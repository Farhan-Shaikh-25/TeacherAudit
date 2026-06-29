import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../utils/cloud_sync_provider.dart';
import '../utils/teaching_subject.dart';
import '../utils/user_profile_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controllers for updating targets
  late TextEditingController _personalTargetController;

  // Controllers for adding a new subject (Updated for new model)
  final _programmeController = TextEditingController();
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();

  final List<String> _classes = ['FY', 'SY', 'TY', 'MSc-I', 'MSc-II'];
  String _selectedClass = 'FY';

  @override
  void initState() {
    super.initState();
    // Fetch current targets from provider to pre-fill the text fields
    final profile = context.read<UserProfileProvider>();
    _personalTargetController = TextEditingController(text: profile.personalTargetHours.toString());
  }

  @override
  void dispose() {
    _personalTargetController.dispose();
    _programmeController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _saveTargets() {
    final personal = double.tryParse(_personalTargetController.text) ?? 2.0;
    context.read<UserProfileProvider>().updatePersonalTarget(personal);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Personal target updated!'), behavior: SnackBarBehavior.floating),
    );
    FocusScope.of(context).unfocus();
  }

  void _addNewSubject() {
    // Validate all required fields
    if (_programmeController.text.trim().isEmpty ||
        _subjectController.text.trim().isEmpty ||
        _roomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all subject configuration fields.')),
      );
      return;
    }

    final newSubject = TeachingSubject(
      programme: _programmeController.text.trim().toUpperCase(),
      year: _selectedClass,
      subjectName: _subjectController.text.trim(),
      roomNo: _roomController.text.trim().toUpperCase(),
    );

    context.read<UserProfileProvider>().addSubject(newSubject);

    // Clear fields (except Programme, to make batch-adding easier)
    _subjectController.clear();
    _roomController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = context.watch<UserProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: TARGET HOURS ---
            Text('Daily Targets', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Daily Goals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '6.67', // Hardcoded visual representation
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Academic (Policy)',
                              border: OutlineInputBorder(),
                              filled: true,
                              suffixText: 'hrs',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _personalTargetController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Personal Target',
                              border: OutlineInputBorder(),
                              filled: true,
                              suffixText: 'hrs',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () {
                          _saveTargets();
                        },
                        child: const Text('Save Target'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- SECTION 2: MANAGE SUBJECTS ---
            Text('Manage Teaching Allocations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Add New Subject Card (Updated for full model)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _programmeController,
                              decoration: const InputDecoration(
                                labelText: 'Programme',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedClass,
                              decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder(), isDense: true),
                              items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) => setState(() => _selectedClass = val!),
                            ),
                          ),
                        ]),
                    const SizedBox(height: 12),
                    Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _subjectController,
                              decoration: const InputDecoration(
                                labelText: 'Subject',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onFieldSubmitted: (_) => _addNewSubject(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _roomController,
                              decoration: const InputDecoration(
                                labelText: 'Room',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onFieldSubmitted: (_) => _addNewSubject(),
                            ),
                          ),
                        ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addNewSubject,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // List of Existing Subjects (Updated UI)
            userProfile.mySubjects.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No teaching allocations configured.')),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: userProfile.mySubjects.length,
              itemBuilder: (context, index) {
                final subject = userProfile.mySubjects[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(Icons.class_outlined, size: 20, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    title: Text('${subject.programme} — ${subject.year}'),
                    subtitle: Text('Subject: ${subject.subjectName}\nRoom: ${subject.roomNo}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        context.read<UserProfileProvider>().removeSubject(subject);
                      },
                    ),
                  ),
                );
              },
            ),
            Text('Cloud Backup & Sync', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Consumer<CloudSyncProvider>(
              builder: (context, cloudProvider, child) {
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            cloudProvider.isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                            color: cloudProvider.isAuthenticated ? Colors.green : Colors.grey,
                            size: 32,
                          ),
                          title: Text(cloudProvider.isAuthenticated ? 'Connected' : 'Not Connected'),
                          subtitle: Text(cloudProvider.connectedEmail ?? 'Sign in to safely backup your audit data.'),
                          trailing: cloudProvider.isAuthenticated
                              ? TextButton(onPressed: cloudProvider.signOut, child: const Text('Disconnect'))
                              : FilledButton.tonal(onPressed: cloudProvider.signIn, child: const Text('Connect Cloud')),
                        ),
                        if (cloudProvider.isAuthenticated) ...[
                          const Divider(height: 24),
                          FilledButton.icon(
                            onPressed: cloudProvider.isSyncing ? null : cloudProvider.syncDatabase,
                            icon: cloudProvider.isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.sync),
                            label: Text(cloudProvider.isSyncing ? 'Syncing...' : 'Backup Database Now'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: cloudProvider.isSyncing ? null : () => cloudProvider.restoreDatabase(context),
                            icon: const Icon(Icons.download),
                            label: const Text('Restore Data from Cloud'),
                          ),
                          if (cloudProvider.lastSyncTime != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Last synced: ${DateFormat('MMM d, h:mm a').format(cloudProvider.lastSyncTime!)}',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}