import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import your models and providers
import '../utils/task_entry.dart';
import '../utils/task_provider.dart';
import '../utils/user_profile_provider.dart';
import '../utils/task_form_provider.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskEntry? taskToEdit;

  const TaskFormScreen({super.key, this.taskToEdit});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers (Updated for the Single Wide Table schema)
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _commentsController;

  // Read-only controller for the auto-filled room
  late TextEditingController _roomController;

  // Cascading Dropdown State (The Funnel)
  String? _selectedProgramme;
  String? _selectedClass;
  String? _selectedSubject;
  String? _selectedDivision; // Added to support the new database schema

  @override
  void initState() {
    super.initState();

    // 1. Initialize text controllers with the saved data
    _titleController = TextEditingController(text: widget.taskToEdit?.title);
    _descriptionController = TextEditingController(text: widget.taskToEdit?.detailedDescription);
    _commentsController = TextEditingController(text: widget.taskToEdit?.comments);
    _roomController = TextEditingController(text: widget.taskToEdit?.roomNo);

    // 2. Initialize cascading dropdowns if it's a teaching task
    if (widget.taskToEdit != null &&
        widget.taskToEdit?.mainModule == MainModule.academic &&
        widget.taskToEdit?.subCategory == 'Teaching') {
      _selectedProgramme = widget.taskToEdit?.programme;
      _selectedClass = widget.taskToEdit?.className;
      _selectedDivision = widget.taskToEdit?.division;
      _selectedSubject = widget.taskToEdit?.subject;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _commentsController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  // --- TIME PICKER LOGIC ---
  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final provider = context.read<TaskFormProvider>();
    final initialTime = isStart
        ? TimeOfDay.fromDateTime(provider.startTime)
        : TimeOfDay.fromDateTime(provider.endTime);

    final pickedTime = await showTimePicker(context: context, initialTime: initialTime);

    if (pickedTime != null) {
      final now = DateTime.now();
      final newDateTime = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);

      if (isStart) {
        if (newDateTime.isAfter(provider.endTime) || newDateTime.isAtSameMomentAs(provider.endTime)) {
          provider.updateTimes(newDateTime, newDateTime.add(const Duration(hours: 1)));
        } else {
          provider.updateTimes(newDateTime, provider.endTime);
        }
      } else {
        if (newDateTime.isBefore(provider.startTime) || newDateTime.isAtSameMomentAs(provider.startTime)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time.')));
          return;
        }
        provider.updateTimes(provider.startTime, newDateTime);
      }
    }
  }

  // --- SUBMIT LOGIC ---
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final formState = context.read<TaskFormProvider>();

      final isTeaching = formState.selectedModule == MainModule.academic &&
          formState.selectedSubCategory == 'Teaching';

      final task = TaskEntry(
        id: widget.taskToEdit?.id,
        startTime: formState.startTime,
        endTime: formState.endTime,
        mainModule: formState.selectedModule,
        subCategory: formState.selectedSubCategory,

        // Generic Text Fields
        title: _titleController.text.isNotEmpty ? _titleController.text : null,
        detailedDescription: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        comments: _commentsController.text.isNotEmpty ? _commentsController.text : null,

        // Teaching Specific Fields (Null if not a teaching task)
        programme: isTeaching ? _selectedProgramme : null,
        className: isTeaching ? _selectedClass : null,
        division: isTeaching ? _selectedDivision : null,
        subject: isTeaching ? _selectedSubject : null,
        roomNo: isTeaching ? _roomController.text : null,
        isExtraLecture: isTeaching ? formState.isExtraLecture : false
      );

      final taskListProvider = context.read<TaskListProvider>();
      final submitAction = widget.taskToEdit == null
          ? taskListProvider.addTask(task)
          : taskListProvider.updateTask(task);

      submitAction.then((_) {
        Navigator.pop(context);
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = context.watch<TaskFormProvider>();
    final userProfile = context.watch<UserProfileProvider>();
    final masterSchedule = userProfile.mySubjects;

    // --- CASCADING FILTER LOGIC ---
    final availableProgrammes = masterSchedule.map((e) => e.programme).toSet().toList();

    final availableClasses = masterSchedule
        .where((e) => e.programme == _selectedProgramme)
        .map((e) => e.year)
        .toSet()
        .toList();

    final availableSubjects = masterSchedule
        .where((e) => e.programme == _selectedProgramme && e.year == _selectedClass)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.taskToEdit != null ? 'Edit Task' : 'Add Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. TIME PICKERS ---
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(TimeOfDay.fromDateTime(formState.startTime).format(context)),
                      trailing: const Icon(Icons.access_time),
                      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () => _pickTime(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(TimeOfDay.fromDateTime(formState.endTime).format(context)),
                      trailing: const Icon(Icons.access_time),
                      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () => _pickTime(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- 2. THE 4-WAY MODULE SELECTOR ---
              DropdownButtonFormField<MainModule>(
                decoration: const InputDecoration(labelText: 'Primary Module', border: OutlineInputBorder()),
                value: formState.selectedModule,
                items: MainModule.values.map((module) {
                  return DropdownMenuItem(value: module, child: Text(module.displayName));
                }).toList(),
                onChanged: (val) => context.read<TaskFormProvider>().updateModule(val!),
              ),
              const SizedBox(height: 16),

              // --- 3. DYNAMIC SUB-CATEGORY DROPDOWN ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Sub-Category', border: OutlineInputBorder()),
                value: formState.selectedSubCategory,
                items: moduleSubCategories[formState.selectedModule]!.map((subCat) {
                  return DropdownMenuItem(value: subCat, child: Text(subCat));
                }).toList(),
                onChanged: (val) => context.read<TaskFormProvider>().updateSubCategory(val!),
              ),
              const SizedBox(height: 24),

              // --- 4. CONDITIONAL TEACHING FUNNEL ---
              if (formState.selectedModule == MainModule.academic && formState.selectedSubCategory == 'Teaching') ...[
                Text('Class Configuration', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 12),

                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Regular')),
                    ButtonSegment(value: true, label: Text('Extra')),
                  ],
                  selected: {formState.isExtraLecture},
                  onSelectionChanged: (set) => context.read<TaskFormProvider>().toggleExtraLecture(set.first),
                ),
                const SizedBox(height: 16),

                if (availableProgrammes.isEmpty)
                  const Text('No teaching schedule configured. Go to settings to add your master timetable.', style: TextStyle(color: Colors.red))
                else ...[
                  // Programme Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Programme', border: OutlineInputBorder()),
                    value: availableProgrammes.contains(_selectedProgramme) ? _selectedProgramme : null,
                    items: availableProgrammes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedProgramme = val;
                        _selectedClass = null;
                        _selectedSubject = null;
                        _roomController.clear();
                      });
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Class & Division Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                          value: availableClasses.contains(_selectedClass) ? _selectedClass : null,
                          items: availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: _selectedProgramme == null ? null : (val) {
                            setState(() {
                              _selectedClass = val;
                              _selectedSubject = null;
                              _roomController.clear();
                            });
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Div (Opt)', border: OutlineInputBorder()),
                          value: _selectedDivision,
                          items: ['A', 'B', 'C', 'D', 'E', 'F'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (val) => setState(() => _selectedDivision = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Subject Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    value: availableSubjects.any((s) => s.subjectName == _selectedSubject) ? _selectedSubject : null,
                    items: availableSubjects.map((s) => DropdownMenuItem(value: s.subjectName, child: Text(s.subjectName))).toList(),
                    onChanged: _selectedClass == null ? null : (val) {
                      setState(() {
                        _selectedSubject = val;
                        final matchedSubject = availableSubjects.firstWhere((s) => s.subjectName == val);
                        _roomController.text = matchedSubject.roomNo;
                      });
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Auto-filled Room
                  TextFormField(
                    controller: _roomController,
                    readOnly: !formState.isExtraLecture, // Unlock if Extra
                    decoration: InputDecoration(
                      labelText: formState.isExtraLecture ? 'Room No. (Customizable)' : 'Room No. (Auto-filled)',
                      border: const OutlineInputBorder(),
                      filled: !formState.isExtraLecture, // Remove grey background if unlocked
                      fillColor: formState.isExtraLecture ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                ]
              ],

              // --- 5. SHARED GENERIC FIELDS ---
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                    labelText: formState.selectedModule == MainModule.personal ? 'Task Title (e.g. Morning Walk)' : 'Specific Title / Focus (Optional)',
                    border: const OutlineInputBorder()
                ),
                validator: (v) => (formState.selectedModule == MainModule.personal && v!.isEmpty) ? 'Required for personal tasks' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Detailed Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _commentsController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Comments / Remarks', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 16),
              Expanded(child: FilledButton(onPressed: _submitForm, child: Text(widget.taskToEdit != null ? 'Update' : 'Save'))),
            ],
          ),
        ),
      ),
    );
  }
}