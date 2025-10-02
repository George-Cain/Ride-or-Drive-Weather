/// Performance dashboard widget for displaying comprehensive performance metrics
/// and optimization recommendations
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/advanced_performance_monitor.dart';
import '../shared/utils/consolidated_utils.dart';

/// Performance dashboard widget with real-time monitoring
class PerformanceDashboard extends StatefulWidget {
  final bool showDetailedMetrics;
  final bool enableRealTimeUpdates;
  final Duration updateInterval;

  const PerformanceDashboard({
    super.key,
    this.showDetailedMetrics = true,
    this.enableRealTimeUpdates = true,
    this.updateInterval = const Duration(seconds: 5),
  });

  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard>
    with TickerProviderStateMixin, ConsolidatedMixin {
  late TabController _tabController;
  Timer? _updateTimer;

  // Subscriptions
  StreamSubscription<PerformanceSnapshot>? _snapshotSubscription;
  StreamSubscription<List<OptimizationRecommendation>>?
      _recommendationSubscription;
  StreamSubscription<PerformanceAlert>? _alertSubscription;

  // State
  Map<String, dynamic> _performanceSummary = {};
  List<OptimizationRecommendation> _recommendations = [];
  List<PerformanceAlert> _recentAlerts = [];
  PerformanceSnapshot? _latestSnapshot;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeMonitoring();
    _setupSubscriptions();

    if (widget.enableRealTimeUpdates) {
      _startPeriodicUpdates();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _updateTimer?.cancel();
    _snapshotSubscription?.cancel();
    _recommendationSubscription?.cancel();
    _alertSubscription?.cancel();
    super.dispose();
  }

  void _initializeMonitoring() {
    _updatePerformanceData();
    _isMonitoring = AdvancedPerformanceMonitor.instance.isMonitoring;
  }

  void _setupSubscriptions() {
    final monitor = AdvancedPerformanceMonitor.instance;

    _snapshotSubscription = monitor.snapshotStream.listen((snapshot) {
      if (mounted) {
        setState(() {
          _latestSnapshot = snapshot;
        });
      }
    });

    _recommendationSubscription =
        monitor.recommendationStream.listen((recommendations) {
      if (mounted) {
        setState(() {
          _recommendations = recommendations;
        });
      }
    });

    _alertSubscription = monitor.alertStream.listen((alert) {
      if (mounted) {
        setState(() {
          _recentAlerts.insert(0, alert);
          // Keep only recent alerts
          if (_recentAlerts.length > 50) {
            _recentAlerts = _recentAlerts.take(50).toList();
          }
        });
        _showAlertSnackBar(alert);
      }
    });
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(widget.updateInterval, (_) {
      _updatePerformanceData();
    });
  }

  void _updatePerformanceData() {
    if (mounted) {
      setState(() {
        _performanceSummary =
            AdvancedPerformanceMonitor.instance.getPerformanceSummary();
        _isMonitoring = AdvancedPerformanceMonitor.instance.isMonitoring;
      });
    }
  }

  void _showAlertSnackBar(PerformanceAlert alert) {
    final severity = alert.issue.severity;
    final message =
        '${alert.issue.type.name.toUpperCase()}: ${alert.issue.description}';

    if (severity == IssueSeverity.critical) {
      showError(context, message, duration: const Duration(seconds: 6));
    } else if (severity == IssueSeverity.warning) {
      EnhancedUIUtils.showWarning(context, message);
    } else {
      showInfo(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Dashboard'),
        actions: [
          IconButton(
            icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleMonitoring,
            tooltip: _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Data'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear History'),
                ),
              ),
              const PopupMenuItem(
                value: 'recommendations',
                child: ListTile(
                  leading: Icon(Icons.lightbulb),
                  title: Text('Generate Recommendations'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.memory), text: 'Metrics'),
            Tab(icon: Icon(Icons.lightbulb_outline), text: 'Recommendations'),
            Tab(icon: Icon(Icons.warning), text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMetricsTab(),
          _buildRecommendationsTab(),
          _buildAlertsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildQuickStatsGrid(),
          const SizedBox(height: 16),
          _buildTrendChart(),
          const SizedBox(height: 16),
          _buildRecentIssuesCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final monitoringDuration = _performanceSummary['monitoring_duration'];
    final isActive = _performanceSummary['monitoring_active'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.monitor_heart : Icons.monitor_heart_outlined,
                  color: isActive ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performance Monitoring',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isActive ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      monitoringDuration != null
                          ? '${monitoringDuration}m'
                          : 'Active',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (monitoringDuration != null) ...[
              const SizedBox(height: 8),
              Text(
                'Running for ${ConsolidatedUtils.formatDuration(Duration(minutes: monitoringDuration))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    final totalSnapshots = _performanceSummary['total_snapshots'] ?? 0;
    final warnings = _performanceSummary['performance_warnings'] ?? 0;
    final criticalIssues = _performanceSummary['critical_issues'] ?? 0;
    final recommendationsCount = _recommendations.length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _buildStatCard(
          'Snapshots',
          totalSnapshots.toString(),
          Icons.camera_alt,
          Colors.blue,
        ),
        _buildStatCard(
          'Warnings',
          warnings.toString(),
          Icons.warning,
          Colors.orange,
        ),
        _buildStatCard(
          'Critical Issues',
          criticalIssues.toString(),
          Icons.error,
          Colors.red,
        ),
        _buildStatCard(
          'Recommendations',
          recommendationsCount.toString(),
          Icons.lightbulb,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    final metricTrends =
        _performanceSummary['metric_trends'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Trends',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (metricTrends.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No trend data available'),
                ),
              )
            else
              ...metricTrends.entries.map((entry) {
                final metricName =
                    ConsolidatedUtils.camelCaseToTitle(entry.key);
                final metricData = entry.value as Map<String, dynamic>;
                final current = metricData['current']?.toDouble() ?? 0.0;
                final trend = metricData['trend']?.toDouble() ?? 0.0;
                final samples = metricData['samples'] ?? 0;

                return _buildTrendItem(metricName, current, trend, samples);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendItem(
      String name, double current, double trend, int samples) {
    final isPositiveTrend = trend > 0;
    final trendColor = isPositiveTrend ? Colors.red : Colors.green;
    final trendIcon = isPositiveTrend ? Icons.trending_up : Icons.trending_down;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              current.toStringAsFixed(1),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(trendIcon, color: trendColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${(trend * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: trendColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$samples samples',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentIssuesCard() {
    final recentIssues = AdvancedPerformanceMonitor.instance.getRecentIssues(
      since: const Duration(hours: 1),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Issues (Last Hour)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (recentIssues.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text('No issues detected'),
                    ],
                  ),
                ),
              )
            else
              ...recentIssues.take(5).map((issue) => _buildIssueItem(issue)),
            if (recentIssues.length > 5)
              TextButton(
                onPressed: () => _tabController.animateTo(3),
                child: Text('View all ${recentIssues.length} issues'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueItem(PerformanceIssue issue) {
    final severityColor = _getSeverityColor(issue.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: severityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  formatRelativeTime(issue.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Chip(
            label: Text(
              issue.severity.name.toUpperCase(),
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: severityColor.withValues(alpha: 0.1),
            side: BorderSide(color: severityColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsTab() {
    if (_latestSnapshot == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for performance data...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMetricSection('Memory Metrics', _latestSnapshot!.memoryMetrics),
          const SizedBox(height: 16),
          _buildMetricSection(
              'Network Metrics', _latestSnapshot!.networkMetrics),
          const SizedBox(height: 16),
          _buildMetricSection('Background Service Metrics',
              _latestSnapshot!.backgroundServiceMetrics),
          const SizedBox(height: 16),
          _buildMetricSection(
              'Platform Metrics', _latestSnapshot!.platformMetrics),
          const SizedBox(height: 16),
          _buildMetricSection('UI Metrics', _latestSnapshot!.uiMetrics),
        ],
      ),
    );
  }

  Widget _buildMetricSection(String title, Map<String, dynamic> metrics) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildMetricTree(metrics),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTree(dynamic data, {int depth = 0}) {
    if (data is Map<String, dynamic>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(left: depth * 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ConsolidatedUtils.camelCaseToTitle(entry.key),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                _buildMetricTree(entry.value, depth: depth + 1),
                const SizedBox(height: 8),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: Text(
          data.toString(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
  }

  Widget _buildRecommendationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Optimization Recommendations',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ElevatedButton.icon(
                onPressed: _generateRecommendations,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recommendations.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No recommendations available'),
                    SizedBox(height: 8),
                    Text(
                      'Start monitoring to generate recommendations',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recommendations.map(
                (recommendation) => _buildRecommendationCard(recommendation)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(OptimizationRecommendation recommendation) {
    final priorityColor = _getPriorityColor(recommendation.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: priorityColor,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(recommendation.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recommendation.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    recommendation.category.name.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    recommendation.priority.name.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: priorityColor.withValues(alpha: 0.1),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Items:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...recommendation.actionItems.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estimated Impact: ${recommendation.estimatedImpact}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance Alerts',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              TextButton.icon(
                onPressed: _clearAlerts,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentAlerts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/icon2.png',
                      width: 64,
                      height: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text('No alerts'),
                  ],
                ),
              ),
            )
          else
            ..._recentAlerts.map((alert) => _buildAlertCard(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(PerformanceAlert alert) {
    final severityColor = _getSeverityColor(alert.issue.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: severityColor,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(alert.issue.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.issue.recommendation),
            const SizedBox(height: 4),
            Text(
              '${formatRelativeTime(alert.timestamp)} • Frequency: ${alert.frequency}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            alert.issue.severity.name.toUpperCase(),
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: severityColor.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Color _getSeverityColor(IssueSeverity severity) {
    switch (severity) {
      case IssueSeverity.info:
        return Colors.blue;
      case IssueSeverity.warning:
        return Colors.orange;
      case IssueSeverity.critical:
        return Colors.red;
    }
  }

  Color _getPriorityColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.low:
        return Colors.green;
      case RecommendationPriority.medium:
        return Colors.orange;
      case RecommendationPriority.high:
        return Colors.red;
      case RecommendationPriority.critical:
        return Colors.purple;
    }
  }

  void _toggleMonitoring() async {
    final monitor = AdvancedPerformanceMonitor.instance;

    if (_isMonitoring) {
      monitor.stopMonitoring();
      if (mounted) showInfo(context, 'Performance monitoring stopped');
    } else {
      await monitor.startMonitoring();
      if (mounted) showSuccess(context, 'Performance monitoring started');
    }

    _updatePerformanceData();
  }

  void _refreshData() {
    _updatePerformanceData();
    showInfo(context, 'Performance data refreshed');
  }

  void _generateRecommendations() {
    final recommendations =
        AdvancedPerformanceMonitor.instance.generateImmediateRecommendations();
    setState(() {
      _recommendations = recommendations;
    });
    showSuccess(context, 'Generated ${recommendations.length} recommendations');
  }

  void _clearAlerts() {
    setState(() {
      _recentAlerts.clear();
    });
    showInfo(context, 'All alerts cleared');
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportPerformanceData();
        break;
      case 'clear':
        _clearPerformanceHistory();
        break;
      case 'recommendations':
        _generateRecommendations();
        break;
    }
  }

  void _exportPerformanceData() {
    final summary = AdvancedPerformanceMonitor.instance.getPerformanceSummary();

    Clipboard.setData(ClipboardData(text: summary.toString()));
    showSuccess(context, 'Performance data copied to clipboard');
  }

  void _clearPerformanceHistory() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Clear Performance History',
      message:
          'This will permanently delete all performance data. Are you sure?',
      confirmText: 'Clear',
      isDangerous: true,
    );

    if (confirmed && mounted) {
      AdvancedPerformanceMonitor.instance.clearHistory();
      setState(() {
        _recentAlerts.clear();
        _recommendations.clear();
      });
      _updatePerformanceData();
      if (mounted) showSuccess(context, 'Performance history cleared');
    }
  }
}
