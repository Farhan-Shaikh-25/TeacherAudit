import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../utils/export_helper.dart';
import '../utils/task_entry.dart';
import '../utils/task_provider.dart';
import '../utils/user_profile_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  MainModule? _selectedCategoryFilter;
  String? _selectedClassFilter;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  List<TaskEntry> _getFilteredTasks(List<TaskEntry> allTasks) {
    return allTasks.where((task) {
      final taskDate = DateTime(task.startTime.year, task.startTime.month, task.startTime.day);
      final startDate = DateTime(_selectedDateRange.start.year, _selectedDateRange.start.month, _selectedDateRange.start.day);
      final endDate = DateTime(_selectedDateRange.end.year, _selectedDateRange.end.month, _selectedDateRange.end.day);

      final isInDateRange = taskDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          taskDate.isBefore(endDate.add(const Duration(days: 1)));
      if (!isInDateRange) return false;

      if (_selectedCategoryFilter != null && task.mainModule != _selectedCategoryFilter) return false;
      if (_selectedClassFilter != null && task.className != _selectedClassFilter) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTasks = context.watch<TaskListProvider>().tasks;
    final userProfile = context.watch<UserProfileProvider>();

    final uniqueClasses = userProfile.mySubjects.map((s) => s.year).toSet().toList();
    final filteredTasks = _getFilteredTasks(allTasks);

    // --- Core Calculations ---
    double academicHours = 0, researchHours = 0, otherHours = 0, personalHours = 0;
    Map<String, double> subCategoryBreakdown = {};
    Map<int, double> dailyAcademicHours = {}; // For the trend chart

    for (var task in filteredTasks) {
      final hours = task.duration.inMinutes / 60.0;

      // Module Totals
      switch (task.mainModule) {
        case MainModule.academic: academicHours += hours; break;
        case MainModule.research: researchHours += hours; break;
        case MainModule.otherWork: otherHours += hours; break;
        case MainModule.personal: personalHours += hours; break;
      }

      // Sub-Category Drill-down
      subCategoryBreakdown[task.subCategory] = (subCategoryBreakdown[task.subCategory] ?? 0) + hours;

      // Daily Trend Data (Only counting Academic/Research/Other for work trends)
      if (task.mainModule != MainModule.personal) {
        final day = task.startTime.day;
        dailyAcademicHours[day] = (dailyAcademicHours[day] ?? 0) + hours;
      }
    }

    final totalHours = academicHours + researchHours + otherHours + personalHours;
    final totalWorkHours = academicHours + researchHours + otherHours;

    // Sort subcategories by most hours
    var sortedSubCategories = subCategoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate Average
    final daysInPeriod = _selectedDateRange.end.difference(_selectedDateRange.start).inDays + 1;
    final avgDailyWork = totalWorkHours / (daysInPeriod > 0 ? daysInPeriod : 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. DATE RANGE ---
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Date Range'),
                subtitle: Text(
                  '${DateFormat('MMM d, yyyy').format(_selectedDateRange.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange.end)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: TextButton(onPressed: _pickDateRange, child: const Text('Change')),
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. HIGH-LEVEL SUMMARY CARDS ---
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                      context,
                      'Avg Daily Work',
                      '${avgDailyWork.toStringAsFixed(1)} h',
                      avgDailyWork >= userProfile.academicTargetHours ? Colors.green : Colors.orange,
                      avgDailyWork >= userProfile.academicTargetHours ? 'Meets Policy' : 'Below Target'
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                      context,
                      'Total Work Logged',
                      '${totalWorkHours.toStringAsFixed(1)} h',
                      theme.colorScheme.primary,
                      '$daysInPeriod Days'
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- 3. DAILY TREND CHART ---
            if (dailyAcademicHours.isNotEmpty) ...[
              Text('Work Trend (Academic/Research/Other)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (userProfile.academicTargetHours * 1.5).clamp(8.0, 15.0), // Scale nicely
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: dailyAcademicHours.entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            color: entry.value >= userProfile.academicTargetHours ? Colors.green : theme.colorScheme.primary,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // --- 4. PIE CHART ---
            Text('Time Distribution', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: totalHours == 0
                  ? const Center(child: Text('No data for this period.'))
                  : PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: [
                    if (academicHours > 0) PieChartSectionData(color: Colors.blue, value: academicHours, title: '${((academicHours/totalHours)*100).toStringAsFixed(0)}%', radius: 60),
                    if (researchHours > 0) PieChartSectionData(color: Colors.purple, value: researchHours, title: '${((researchHours/totalHours)*100).toStringAsFixed(0)}%', radius: 60),
                    if (otherHours > 0) PieChartSectionData(color: Colors.orange, value: otherHours, title: '${((otherHours/totalHours)*100).toStringAsFixed(0)}%', radius: 60),
                    if (personalHours > 0) PieChartSectionData(color: Colors.green, value: personalHours, title: '${((personalHours/totalHours)*100).toStringAsFixed(0)}%', radius: 60),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            if (totalHours > 0)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(Colors.blue, 'Academic (${academicHours.toStringAsFixed(1)}h)'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.purple, 'Research (${researchHours.toStringAsFixed(1)}h)'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(Colors.orange, 'Other (${otherHours.toStringAsFixed(1)}h)'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.green, 'Personal (${personalHours.toStringAsFixed(1)}h)'),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 32),

            // --- 5. SUB-CATEGORY DRILL-DOWN ---
            if (sortedSubCategories.isNotEmpty) ...[
              Text('Top Activities Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: sortedSubCategories.take(5).map((entry) {
                      final percentage = entry.value / totalHours;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('${entry.value.toStringAsFixed(1)}h', style: TextStyle(color: theme.colorScheme.outline)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              color: theme.colorScheme.primary,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // --- 6. FILTERS ---
            Text('Filter Chart Data', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: MainModule.values.map((category) {
                return FilterChip(
                  label: Text(category.displayName),
                  selected: _selectedCategoryFilter == category,
                  onSelected: (selected) => setState(() => _selectedCategoryFilter = selected ? category : null),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (uniqueClasses.isNotEmpty) ...[
              Text('Filter By Class', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: uniqueClasses.map((className) {
                  return FilterChip(
                    label: Text(className),
                    selected: _selectedClassFilter == className,
                    onSelected: (selected) => setState(() => _selectedClassFilter = selected ? className : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
            ],

            // --- 7. EXPORT ACTIONS ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (filteredTasks.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
                        return;
                      }
                      ExportHelper.exportToExcel(context, filteredTasks);
                    },
                    icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
                    label: const Text('Excel (.xlsx)'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (filteredTasks.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
                        return;
                      }
                      ExportHelper.exportToPdf(context, filteredTasks);
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF Report'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, Color color, String subtitle) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}