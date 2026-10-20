import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/unit_preferences.dart';
import '../theme/design_tokens.dart';
import '../widgets/karipa_feedback.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  String? _error;
  DateTime? _periodStart;
  DateTime? _periodEnd;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getWeeklyLeaderboard();
      final rawEntries = data['entries'] as List;
      if (!mounted) return;
      setState(() {
        _periodStart = DateTime.tryParse(data['periodStart']?.toString() ?? '');
        _periodEnd = DateTime.tryParse(data['periodEnd']?.toString() ?? '');
        _entries = rawEntries
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _periodLabel() {
    final start = _periodStart;
    final end = _periodEnd;
    if (start == null || end == null) {
      return 'Sunday–Saturday · Philippine time';
    }
    const manilaOffset = Duration(hours: 8);
    final manilaStart = start.toUtc().add(manilaOffset);
    final manilaEnd = end.toUtc().add(manilaOffset);
    String dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';
    return '${dateLabel(manilaStart)} – ${dateLabel(manilaEnd)} · Philippine time';
  }

  void _onNavigationTapped(int index) {
    if (index == 1) return;
    final route = switch (index) {
      0 => '/home',
      2 => '/activity_history',
      3 => '/profile',
      _ => '/home',
    };
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final units = context.watch<UnitPreferences>();
    final auth = context.watch<AuthService>();
    Map<String, dynamic>? currentUserEntry;
    for (final entry in _entries) {
      if (entry['isCurrentUser'] == true) {
        currentUserEntry = entry;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh leaderboard',
            onPressed: _isLoading ? null : _loadLeaderboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLeaderboard,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: KaripaPalette.navy,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.leaderboard,
                        color: KaripaPalette.white, size: 30),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Move together this week',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: KaripaPalette.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Verified members with a completed activity are ranked by distance each week. The leaderboard resets every Sunday at midnight Philippine time.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: KaripaPalette.ivory),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _periodLabel(),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: KaripaPalette.ivory),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                KaripaFeedback(
                  title: 'Could not load the leaderboard',
                  message: _error!,
                  kind: FeedbackKind.error,
                  actionLabel: 'Retry',
                  onAction: _loadLeaderboard,
                )
              else if (_entries.isEmpty)
                const KaripaFeedback(
                  title: 'A fresh week starts here',
                  message:
                      'No verified members have recorded activity distance this week yet. Complete and save an activity to appear here.',
                  kind: FeedbackKind.empty,
                )
              else ...[
                if (currentUserEntry != null) ...[
                  _YourRankCard(
                    rank: (currentUserEntry['rank'] as num).toInt(),
                    distance: units.formatDistance(
                      (currentUserEntry['distanceMeters'] as num).toDouble() /
                          1000,
                    ),
                    name: auth.name ?? 'You',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  'Top members',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._entries.map((entry) {
                  final rank = (entry['rank'] as num).toInt();
                  final name = entry['isCurrentUser'] == true
                      ? (auth.name ?? entry['name'] as String)
                      : entry['name'] as String;
                  final distance = units.formatDistance(
                    (entry['distanceMeters'] as num).toDouble() / 1000,
                  );
                  return Card(
                    key: ValueKey('leaderboard-rank-$rank'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: rank <= 3
                            ? KaripaPalette.navy
                            : colors.surfaceContainerHighest,
                        foregroundColor:
                            rank <= 3 ? KaripaPalette.white : colors.onSurface,
                        child: Text('$rank'),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: entry['isCurrentUser'] == true
                          ? const Text('You')
                          : null,
                      trailing: Text(
                        distance,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Only display names and total distances are shown. Activity details are private.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: _onNavigationTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined), label: 'Leaderboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined), label: 'History'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _YourRankCard extends StatelessWidget {
  final int rank;
  final String distance;
  final String name;
  final ColorScheme colors;

  const _YourRankCard({
    required this.rank,
    required this.distance,
    required this.name,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.person_pin_circle_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your weekly rank',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(
              '#$rank · $distance',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
