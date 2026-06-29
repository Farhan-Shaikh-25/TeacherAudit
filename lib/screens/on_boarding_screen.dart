import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/teaching_subject.dart';
import '../utils/user_profile_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TeachingSubject> _tempSubjects = [];

  // Form Field Controllers
  final _programmeController = TextEditingController();
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();

  // Controllers for Daily Target Hours
  final _personalTargetController = TextEditingController(text: '2.0');

  // Standardised Class Dropdown options
  final List<String> _classes = ['FY', 'SY', 'TY', 'MSc-I', 'MSc-II'];
  String _selectedClass = 'FY';

  @override
  void dispose() {
    _programmeController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    _personalTargetController.dispose();
    super.dispose();
  }

  void _addSubjectToSchedule() {
    // Validate only the subject creation block fields
    if (_programmeController.text.trim().isEmpty ||
        _subjectController.text.trim().isEmpty ||
        _roomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all teaching profile fields.')),
      );
      return;
    }

    setState(() {
      _tempSubjects.add(
        TeachingSubject(
          programme: _programmeController.text.trim().toUpperCase(),
          year: _selectedClass,
          subjectName: _subjectController.text.trim(),
          roomNo: _roomController.text.trim().toUpperCase(),
        ),
      );

      // Clear inputs except Programme to make continuous entry faster
      _subjectController.clear();
      _roomController.clear();
    });
  }

  void _finishSetup() {
    if (_tempSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one teaching schedule entry.')),
      );
      return;
    }

    final personalTarget = double.tryParse(_personalTargetController.text) ?? 2.0;

    // Save everything to the provider
    context.read<UserProfileProvider>().completeSetup(
      subjects: _tempSubjects,
      personalTarget: personalTarget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Professor!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set up your targets and regular teaching configurations.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // --- 1. DAILY TARGETS SECTION ---
                Text('Daily Goals (Hours)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '6.67',
                        readOnly: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Academic Target',
                          border: OutlineInputBorder(),
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
                          suffixText: 'hrs',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // --- 2. MULTI-FIELD MASTER PROFILE ENTRY ---
                Text('Teaching Allocations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Row for Programme and Class
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _programmeController,
                        decoration: const InputDecoration(
                          labelText: 'Programme',
                          hintText: 'e.g. BSc / MCA',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                        items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _selectedClass = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row for Subject and Room No
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name',
                          hintText: 'e.g. Calculus',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _roomController,
                        decoration: const InputDecoration(
                          labelText: 'Room No.',
                          hintText: 'e.g. 302',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: _addSubjectToSchedule,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Add to Master Schedule'),
                ),
                const SizedBox(height: 24),

                // --- 3. SCHEDULE DISPLAY LIST ---
                Text(
                  'Configured Profile Matrix',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 8),

                _tempSubjects.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No teaching combinations configured yet.'),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tempSubjects.length,
                  itemBuilder: (context, index) {
                    final item = _tempSubjects[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(Icons.class_outlined, color: theme.colorScheme.primary),
                        title: Text('${item.programme} — ${item.year}'),
                        subtitle: Text('Subject: ${item.subjectName}\nRoom: ${item.roomNo}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => setState(() => _tempSubjects.removeAt(index)),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FilledButton(
            onPressed: _finishSetup,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('Complete Onboarding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}