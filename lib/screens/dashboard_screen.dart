import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:task_time/screens/analytics_screen.dart';
import 'package:task_time/screens/settings_screen.dart';
import 'package:task_time/utils/task_entry.dart';
import 'package:task_time/utils/task_form_provider.dart';
import 'package:task_time/utils/task_provider.dart';
import '../utils/user_profile_provider.dart';
import 'task_form_screen.dart'; // Add this to pubspec.yaml for date formatting

// Make sure to import your models, providers, and AddTaskScreen here

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Example target: 8 hours per day


  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>();
    final academicTargetHours = userProfile.academicTargetHours;
    final personalTargetHours = userProfile.personalTargetHours;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Audit'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              // Navigate to Analytics Screen (Screen 3)
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AnalyticsScreen()
                )
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<TaskListProvider>(
        builder: (context, taskProvider, child) {
          if (taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (taskProvider.error != null) {
            return Center(child: Text('Error: ${taskProvider.error}'));
          }

          // 1. Calculate Today's Stats
          final now = DateTime.now();
          final todayTasks = taskProvider.tasks.where((t) =>
              t.startTime.year == now.year &&
              t.startTime.month == now.month &&
              t.startTime.day == now.day
          ).toList();

          // Separate tasks
          final academicTasks = todayTasks.where((t) => t.isAcademicTarget).toList();
          final personalTasks = todayTasks.where((t) => !t.isAcademicTarget).toList();

          // Calculate Academic
          int academicMinutes = 0;
          for (var task in academicTasks) {
            academicMinutes += task.duration.inMinutes;
          }
          final double academicHours = academicMinutes / 60.0;
          final bool isAcademicSurplus = academicHours >= academicTargetHours;
          final double academicDiff = (academicHours - academicTargetHours).abs();
          final double academicProgress = (academicHours / academicTargetHours).clamp(0.0, 1.0);

          // Calculate Personal
          int personalMinutes = 0;
          for (var task in personalTasks) {
            personalMinutes += task.duration.inMinutes;
          }
          final double personalHours = personalMinutes / 60.0;
          final bool isPersonalSurplus = personalHours >= personalTargetHours;
          final double personalDiff = (personalHours - personalTargetHours).abs();
          final double personalProgress = (personalHours / personalTargetHours).clamp(0.0, 1.0);

          // 2. Get Last 3 Entries
          final recentTasks = taskProvider.tasks.take(3).toList();

          return RefreshIndicator(
            onRefresh: () => taskProvider.loadTasks(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP: SUMMARY CARDS ---
                  _buildSummaryCard(
                    context: context,
                    academicHours: academicHours,
                    isAcademicSurplus: isAcademicSurplus,
                    academicDiff: academicDiff,
                    academicProgress: academicProgress,
                    personalHours: personalHours,
                    isPersonalSurplus: isPersonalSurplus,
                    personalDiff: personalDiff,
                    personalProgress: personalProgress,
                  ),
                  const SizedBox(height: 32),

                  // --- MIDDLE: RECENT ACTIVITY ---
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (recentTasks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No recent tasks. Add one to get started!'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentTasks.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        return _buildTaskTile(context, recentTasks[index], taskProvider);
                      },
                    ),

                  // Extra padding at the bottom to ensure the FAB doesn't cover content
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),

      // --- BOTTOM: FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => TaskFormProvider(),
                child: const TaskFormScreen(), // Your Screen 2
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add New Task'),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSummaryCard({
    required BuildContext context,
    // Academic Stats
    required double academicHours,
    required bool isAcademicSurplus,
    required double academicDiff,
    required double academicProgress,
    // Personal Stats
    required double personalHours,
    required bool isPersonalSurplus,
    required double personalDiff,
    required double personalProgress,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Top Section: Academic
            _buildStatsRow(
              context: context,
              title: 'Academic Hours',
              hours: academicHours,
              isSurplus: isAcademicSurplus,
              difference: academicDiff,
              progress: academicProgress,
              ringColor: colorScheme.primary,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1, thickness: 1),
            ),

            // Bottom Section: Personal (Non-Academic)
            _buildStatsRow(
              context: context,
              title: 'Personal Hours',
              hours: personalHours,
              isSurplus: isPersonalSurplus,
              difference: personalDiff,
              progress: personalProgress,
              ringColor: colorScheme.tertiary, // Distinct color for personal tasks
            ),
          ],
        ),
      ),
    );
  }

// Reusable helper method for each row
  Widget _buildStatsRow({
    required BuildContext context,
    required String title,
    required double hours,
    required bool isSurplus,
    required double difference,
    required double progress,
    required Color ringColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Side: Text Summaries
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hours.toStringAsFixed(1)}h',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSurplus ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSurplus
                      ? '+${difference.toStringAsFixed(1)}h Surplus'
                      : '-${difference.toStringAsFixed(1)}h Deficit',
                  style: TextStyle(
                    color: isSurplus ? Colors.green.shade800 : Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right Side: Progress Ring
        SizedBox(
          width: 75, // Slightly smaller to fit two comfortably on screen
          height: 75,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: colorScheme.surface.withOpacity(0.4),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSurplus ? Colors.green : ringColor,
                ),
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTile(BuildContext context, TaskEntry task, TaskListProvider provider) {
    final dateFormat = DateFormat('h:mm a');
    final timeString = '${dateFormat.format(task.startTime)} - ${dateFormat.format(task.endTime)}';

    // 1. Determine Title based on new schema
    String title = task.title ?? task.subCategory;
    String? subtitleText = task.detailedDescription;

    // Override for Teaching to show the Class and Subject
    if (task.mainModule == MainModule.academic && task.subCategory == 'Teaching') {
      title = '${task.className ?? ''} ${task.division ?? ''} - ${task.subject ?? ''}';
      subtitleText = task.title ?? task.detailedDescription; // Fallback to title if they entered a specific topic
    }

    return ListTile(
      onTap: () => _showTaskDetailsBottomSheet(context, task),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: task.isAcademicTarget
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        child: Icon(
          task.isAcademicTarget ? Icons.school : Icons.person,
          color: task.isAcademicTarget
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitleText != null && subtitleText.isNotEmpty)
            Text(subtitleText, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          Text(timeString, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider(
                  create: (_) => TaskFormProvider(initialTask: task),
                  child: TaskFormScreen(taskToEdit: task),
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => provider.deleteTask(task.id),
          ),
        ],
      ),
    );
  }

  void _showTaskDetailsBottomSheet(BuildContext context, TaskEntry task) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Calculate exact duration
    final duration = task.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationString = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows it to expand for very long text
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, // Starts at 50% screen height
          minChildSize: 0.3,
          maxChildSize: 0.9,     // Expands to 90% if text is huge
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Tags
                  Row(
                    children: [
                      Chip(
                        label: Text(task.mainModule.displayName),
                        backgroundColor: theme.colorScheme.primaryContainer,
                        labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 8),
                      Chip(label: Text(task.subCategory)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title / Class Info
                  Text(
                    task.title ?? task.subCategory,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),

                  if (task.mainModule == MainModule.academic && task.subCategory == 'Teaching') ...[
                    const SizedBox(height: 8),
                    Text(
                      '${task.className ?? ''} ${task.division ?? ''} - ${task.subject ?? ''}',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                    if (task.roomNo != null)
                      Text('Room: ${task.roomNo} ${task.isExtraLecture ? "(Extra Lecture)" : ""}', style: theme.textTheme.bodyMedium),
                  ],
                  const Divider(height: 32),

                  // Time Information
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${timeFormat.format(task.startTime)} - ${timeFormat.format(task.endTime)}  ($durationString)',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(dateFormat.format(task.startTime), style: theme.textTheme.bodyLarge),
                    ],
                  ),
                  const Divider(height: 32),

                  // Detailed Description
                  if (task.detailedDescription != null && task.detailedDescription!.isNotEmpty) ...[
                    Text('Detailed Description', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    Text(task.detailedDescription!, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 24),
                  ],

                  // Comments
                  if (task.comments != null && task.comments!.isNotEmpty) ...[
                    Text('Comments / Remarks', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Text(task.comments!, style: theme.textTheme.bodyMedium),
                    ),
                  ],

                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            );
          },
        );
      },
    );
  }
}