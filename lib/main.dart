import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_time/screens/dashboard_screen.dart';
import 'package:task_time/screens/on_boarding_screen.dart';
import 'package:task_time/utils/cloud_sync_provider.dart';
import 'package:task_time/utils/task_provider.dart';
import 'package:task_time/utils/task_repository.dart';
import 'package:task_time/utils/user_profile_provider.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NEW: Desktop SQLite Initialization
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(
    MultiProvider(
      providers: [
        // 1. Provide the Repository (Standard Provider since it doesn't change)
        Provider<TaskRepository>(create: (_) => TaskRepository()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => CloudSyncProvider()),
        // 2. Provide the TaskList, injecting the Repository into it
        ChangeNotifierProxyProvider<TaskRepository, TaskListProvider>(
          create: (context) => TaskListProvider(context.read<TaskRepository>()),
          update: (context, repository, previousListProvider) =>
          previousListProvider ?? TaskListProvider(repository),
        ),
      ],
      child: const TeacherAuditApp(),
    ),
  );
}

class TeacherAuditApp extends StatelessWidget {
  const TeacherAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Teacher Audit App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: Consumer<UserProfileProvider>(
        builder: (context, profile, child) {
          if(!profile.isFirstTime) return const DashboardScreen();
          return const OnboardingScreen();
        }
        ),
    );
  }
}