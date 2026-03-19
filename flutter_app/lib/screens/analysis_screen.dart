import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  WeeklyReport? _weeklyReport;
  MonthlyReport? _monthlyReport;
  PerformanceSummary? _summary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final weekly = await ReportService.fetchWeeklyReport();
    final monthly = await ReportService.fetchMonthlyReport();
    final summary = await ReportService.fetchPerformanceSummary();
    
    if (mounted) {
      setState(() {
        _weeklyReport = weekly;
        _monthlyReport = monthly;
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Analysis & Reports'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentViolet,
          labelColor: AppTheme.accentViolet,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentViolet))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyTab(),
                _buildMonthlyTab(),
                _buildSummaryTab(),
              ],
            ),
    );
  }

  Widget _buildWeeklyTab() {
    if (_weeklyReport == null) {
      return const Center(child: Text('Failed to load weekly report', style: TextStyle(color: AppTheme.textMuted)));
    }
    return _buildBarChart(
      title: 'Activity Past 7 Days',
      labels: _weeklyReport!.labels,
      focusTime: _weeklyReport!.focusTime,
      distractionTime: _weeklyReport!.distractionTime,
    );
  }

  Widget _buildMonthlyTab() {
    if (_monthlyReport == null) {
      return const Center(child: Text('Failed to load monthly report', style: TextStyle(color: AppTheme.textMuted)));
    }
    return _buildBarChart(
      title: 'Activity Past 4 Weeks',
      labels: _monthlyReport!.labels,
      focusTime: _monthlyReport!.focusTime,
      distractionTime: _monthlyReport!.distractionTime,
    );
  }

  Widget _buildBarChart({
    required String title,
    required List<String> labels,
    required List<int> focusTime,
    required List<int> distractionTime,
  }) {
    double maxY = 0;
    for (int t in focusTime) if (t > maxY) maxY = t.toDouble();
    for (int t in distractionTime) if (t > maxY) maxY = t.toDouble();
    maxY = (maxY * 1.2).ceilToDouble(); // Add headroom
    if (maxY == 0) maxY = 60; // Default

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(labels[value.toInt()], style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false), // Hide Y axis numbers
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(labels.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: focusTime[i].toDouble(),
                        color: AppTheme.accentEmerald,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: distractionTime[i].toDouble(),
                        color: AppTheme.accentRose,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(color: AppTheme.accentEmerald, label: 'Focus Time (min)'),
              const SizedBox(width: 24),
              _buildLegend(color: AppTheme.accentRose, label: 'Distraction (min)'),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      ],
    );
  }

  Widget _buildSummaryTab() {
    if (_summary == null) {
      return const Center(child: Text('Failed to load summary', style: TextStyle(color: AppTheme.textMuted)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Productivity',
                  value: '${_summary!.productivityScore}%',
                  icon: Icons.bolt,
                  color: AppTheme.accentViolet,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Task Completion',
                  value: '${_summary!.taskCompletionRate}%',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.accentEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Focus',
                  value: '${_summary!.focusTimeTotal}m',
                  icon: Icons.timer,
                  color: AppTheme.accentEmerald,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Distraction',
                  value: '${_summary!.distractionTimeTotal}m',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.accentRose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Top Distracting Apps', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._summary!.topDistractedApps.map((app) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_android, color: AppTheme.textSecondary),
                title: Text(app.name, style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: Text('${app.minutes} min', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
              )).toList(),
          if (_summary!.topDistractedApps.isEmpty)
            const Text('No distraction data logged yet.', style: TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w800)),
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}
