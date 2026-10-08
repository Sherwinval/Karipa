import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/activity_model.dart';
import '../widgets/metric_tile.dart';

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
      Navigator.pushNamed(context, '/activity_history').then((_) => _loadUserDashboard());
    } else if (index == 2) {
      Navigator.pushNamed(context, '/profile').then((_) => _loadUserDashboard());
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.explore, color: Color(0xFF0D9488), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'PathCraft',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Color(0xFF0D9488), size: 28),
            onPressed: () => Navigator.pushNamed(context, '/profile').then((_) => _loadUserDashboard()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserDashboard,
        color: const Color(0xFF0D9488),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              Text(
                'Hello, $userName 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to plan and conquer your next route?',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Hero: Primary Start Activity Action Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'AI-POWERED ROUTING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 22),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Start Outdoor Activity',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose walking, jogging, running, or cycling. Generate and rank smart OSM routes from your GPS location.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/activity_selection');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.navigation_outlined, size: 20),
                      label: const Text(
                        'Start Activity',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Statistics Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Activity Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Real Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Distance',
                      value: _totalDistanceKm.toStringAsFixed(1),
                      unit: 'km',
                      icon: Icons.straighten,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Activities',
                      value: _activities.length.toString(),
                      unit: 'total',
                      icon: Icons.fitness_center,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Active Time',
                      value: _formatTotalTime(_totalDurationSeconds),
                      icon: Icons.timer_outlined,
                      color: Colors.indigo.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Burned',
                      value: _totalCalories.toStringAsFixed(0),
                      unit: 'kcal',
                      icon: Icons.local_fire_department,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Recent Activities Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/activity_history'),
                    child: const Text('View All', style: TextStyle(color: Color(0xFF0D9488))),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                  ),
                )
              else if (_activities.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.directions_run_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No activities recorded yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Press "Start Activity" to generate your first route and track your GPS fitness workout.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ..._activities.take(3).map((a) => _buildRecentActivityCard(a)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavigationTapped,
        selectedItemColor: const Color(0xFF0D9488),
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(ActivityModel activity) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_getActivityIcon(activity.activityType), color: const Color(0xFF0D9488)),
        ),
        title: Text(
          activity.activityType.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${activity.distanceKm.toStringAsFixed(2)} km • ${activity.formattedDuration} • ${activity.calories?.toStringAsFixed(0) ?? '0'} kcal',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.pushNamed(context, '/activity_details', arguments: {'activity': activity});
        },
      ),
    );
  }
}
