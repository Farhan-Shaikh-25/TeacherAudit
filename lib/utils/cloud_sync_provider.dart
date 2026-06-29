import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'database_helper.dart'; // To get the local DB path
import 'google_auth_client.dart'; // The client we just made

class CloudSyncProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isSyncing = false;
  String? _connectedEmail;
  DateTime? _lastSyncTime;

  // Configure Google Sign In to ONLY ask for the hidden App Data folder
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  AutoRefreshingAuthClient? _desktopAuthClient;

  bool get isAuthenticated => _isAuthenticated;
  bool get isSyncing => _isSyncing;
  String? get connectedEmail => _connectedEmail;
  DateTime? get lastSyncTime => _lastSyncTime;

  // --- 1. SIGN IN ---
  Future<void> signIn() async {
    try {
      if(Platform.isWindows || Platform.isLinux || Platform.isMacOS){
        _desktopAuthClient = await _getDesktopClient();
        _isAuthenticated = true;
        _connectedEmail = "PC Connected User";
        notifyListeners();
      }
      else{
        final account = await _googleSignIn.signIn();
        if (account != null) {
        _isAuthenticated = true;
        _connectedEmail = account.email;
        notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
    }
  }

  Future<AutoRefreshingAuthClient> _getDesktopClient() async {
    // 1. Your Desktop Credentials from Google Cloud Console
    const clientId = '951127785891-9vg9n99qjhiagdd1d7e6k87rgsdo99am.apps.googleusercontent.com';
    const clientSecret = String.fromEnvironment('OAUTH_SECRET', defaultValue: '');
    final scopes = [drive.DriveApi.driveAppdataScope];

    // 2. Spin up a temporary local server on an open port
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://localhost:${server.port}';

    // 3. Create the Google Login URL
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
    });

    // 4. Open the user's default web browser
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl);
    } else {
      throw Exception('Could not launch browser.');
    }

    // 5. Wait for Google to redirect back to our local server
    final request = await server.first;
    final code = request.uri.queryParameters['code'];

    // Send a success message to the browser so the tab doesn't look broken
    request.response
      ..statusCode = 200
      ..headers.set('content-type', 'text/html; charset=utf-8')
      ..write('<html><body style="font-family: sans-serif; text-align: center; margin-top: 50px;"><h1>Login successful!</h1><p>You can close this tab and return to the app.</p></body></html>');
    await request.response.close();
    await server.close();

    if (code == null) throw Exception('Authorization failed.');

    // 6. Exchange the code for the actual access tokens
    final tokenResponse = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    final tokenData = jsonDecode(tokenResponse.body);

    // 7. Plug the tokens into googleapis_auth and return the client!
    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        tokenData['access_token'],
        DateTime.now().toUtc().add(Duration(seconds: tokenData['expires_in'])),
      ),
      tokenData['refresh_token'],
      scopes,
    );

    return autoRefreshingClient(ClientId(clientId, clientSecret), credentials, http.Client());
  }

  Future<drive.DriveApi> _getDriveApi() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      if (_desktopAuthClient == null) throw Exception("Desktop user not authenticated");
      return drive.DriveApi(_desktopAuthClient!);
    } else {
      final account = _googleSignIn.currentUser;
      if (account == null) throw Exception("Mobile user not authenticated");
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      return drive.DriveApi(authenticateClient);
    }
  }

  // --- 2. SIGN OUT ---
  Future<void> signOut() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _desktopAuthClient?.close();
      _desktopAuthClient = null;
    } else {
      await _googleSignIn.signOut();
    }
    _isAuthenticated = false;
    _connectedEmail = null;
    notifyListeners();
  }

  // --- 3. UPLOAD TO DRIVE ---
  Future<void> syncDatabase() async {
    if (!_isAuthenticated) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final driveApi = await _getDriveApi();

      // 2. Get the local database file
      final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
      final file = File(dbPath);
      if (!await file.exists()) throw Exception("Database not found");

      // 3. Search Drive to see if we already have a backup
      final fileName = p.basename(dbPath);
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName'",
      );

      final media = drive.Media(file.openRead(), file.lengthSync());

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // UPDATE EXISTING FILE
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          fileId,
          uploadMedia: media,
        );
        debugPrint('Database updated successfully.');
      } else {
        // CREATE NEW BACKUP
        final driveFile = drive.File()
          ..name = fileName
          ..parents = ['appDataFolder'];

        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
        debugPrint('New database backup created.');
      }

      _lastSyncTime = DateTime.now();

    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- 4. RESTORE FROM DRIVE ---
  Future<void> restoreDatabase(BuildContext context) async {
    if (!_isAuthenticated) return;

    _isSyncing = true;
    notifyListeners();

    try {
      // 1. Authenticate the API Client
      final driveApi = await _getDriveApi();

      // 2. Search Drive for the backup
      final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
      final fileName = p.basename(dbPath);

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName'",
      );

      // 3. Download if it exists
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;

        final drive.Media media = await driveApi.files.get(
            fileId,
            downloadOptions: drive.DownloadOptions.fullMedia
        ) as drive.Media;

        // 4. Overwrite the local SQLite file
        final saveFile = File(dbPath);
        final sink = saveFile.openWrite();
        await media.stream.forEach((List<int> chunk) {
          sink.add(chunk);
        });
        await sink.flush();
        await sink.close();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup restored successfully! Please completely close and restart the app to load your data.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No backup found in your Google Drive.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Restore failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}