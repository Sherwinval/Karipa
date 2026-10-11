import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/activity_model.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/home_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  List<ActivityModel> _activities = [];

  double _totalDistanceKm = 0.0;
  int _totalDurationSeconds = 0;
  double _totalCalories = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserDashboard();
  }

  Future<void> _loadUserDashboard() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getActivities();
      double dist = 0;
      int dur = 0;
      double cal = 0;

      for (var a in list) {
        dist += a.distanceKm;
        dur += a.durationSeconds;
        cal += (a.calories ?? 0.0);
      }

      if (mounted) {
        setState(() {
          _activities = list;
          _totalDistanceKm = dist;
          _totalDurationSeconds = dur;
          _totalCalories = cal;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onNavigationTapped(int index) {
    if (index == _currentIndex) return;
    if (index == 1) {
      Navigator.pushNamed(context, '/activity_history')
          .then((_) => _loadUserDashboard());
    } else if (index == 2) {
      Navigator.pushNamed(context, '/profile')
          .then((_) => _loadUserDashboard());
    }
  }

  String _formatTotalTime(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      case 'jogging':
      case 'running':
      default:
        return Icons.directions_run;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final userName = auth.name ?? 'Athlete';

    return Theme(
      data: AppTheme.darkTheme,
      child: HomeDashboard(
        userName: userName,
        isLoading: _isLoading,
        distance: _totalDistanceKm.toStringAsFixed(1),
        activityCount: _activities.length.toString(),
        activeTime: _formatTotalTime(_totalDurationSeconds),
        calories: _totalCalories.toStringAsFixed(0),
        recentActivities:
            _activities.take(3).map(_buildRecentActivityCard).toList(),
        currentIndex: _currentIndex,
        onRefresh: _loadUserDashboard,
        onNavigationTapped: _onNavigationTapped,
        onProfile: () => Navigator.pushNamed(context, '/profile')
            .then((_) => _loadUserDashboard()),
        onStartActivity: () {
          Navigator.pushNamed(context, '/activity_selection');
        },
        onViewAll: () => Navigator.pushNamed(context, '/activity_history'),
      ),
    );
  }

  Widget _buildRecentActivityCard(ActivityModel activity) {
    return HomeRecentActivityCard(
      activity: activity.activityType.toUpperCase(),
      icon: _getActivityIcon(activity.activityType),
      date: DateFormat('d MMM yyyy').format(activity.startedAt),
      distance: activity.distanceKm.toStringAsFixed(2),
      duration: activity.formattedDuration,
      calories: activity.calories?.toStringAsFixed(0) ?? '0',
      onTap: () {
        Navigator.pushNamed(context, '/activity_details',
            arguments: {'activity': activity});
      },
    );
  }
}
