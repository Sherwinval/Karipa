import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/activity_selection_card.dart';
import '../widgets/karipa_button.dart';
import '../widgets/karipa_feedback.dart';

enum _RecordingMode { planRoute, freeRecording }

class ActivitySelectionScreen extends StatefulWidget {
  const ActivitySelectionScreen({super.key});

  @override
  State<ActivitySelectionScreen> createState() =>
      _ActivitySelectionScreenState();
}

class _ActivitySelectionScreenState extends State<ActivitySelectionScreen> {
  String _selectedActivity = 'running';
  _RecordingMode _mode = _RecordingMode.planRoute;
  bool _isNavigating = false;
  String? _navigationError;

  static const _activities = [
    (id: 'walking', label: 'Walking', icon: Icons.directions_walk),
    (id: 'jogging', label: 'Jogging', icon: Icons.directions_run),
    (id: 'running', label: 'Running', icon: Icons.directions_run_outlined),
    (id: 'cycling', label: 'Cycling', icon: Icons.directions_bike),
  ];

  Future<void> _continue() async {
    if (_isNavigating ||
        !_activities.any((item) => item.id == _selectedActivity)) return;
    setState(() {
      _isNavigating = true;
      _navigationError = null;
    });
    try {
      if (_mode == _RecordingMode.planRoute) {
        await Navigator.pushNamed(context, '/route_planning',
            arguments: {'activity': _selectedActivity});
      } else {
        await Navigator.pushNamed(context, '/active_tracking', arguments: {
          'activity': _selectedActivity,
          'recordingMode': 'free_recording',
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => _navigationError =
            'Could not open the next screen. Please try again.');
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = AppSpacing.pageMargin(MediaQuery.sizeOf(context).width);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Activity')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(margin),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                        header: true,
                        child: Text("What's your next move?",
                            style: theme.textTheme.headlineSmall)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Select an activity and how you want to record it.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xl),
                    for (int row = 0; row < 2; row++) ...[
                      if (row > 0) const SizedBox(height: AppSpacing.md),
                      IntrinsicHeight(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            for (int column = 0; column < 2; column++) ...[
                              if (column > 0)
                                const SizedBox(width: AppSpacing.md),
                              Expanded(
                                  child: ActivitySelectionCard(
                                label: _activities[row * 2 + column].label,
                                icon: _activities[row * 2 + column].icon,
                                selected: _selectedActivity ==
                                    _activities[row * 2 + column].id,
                                onTap: _isNavigating
                                    ? null
                                    : () => setState(() {
                                          _selectedActivity =
                                              _activities[row * 2 + column].id;
                                          _navigationError = null;
                                        }),
                              )),
                            ],
                          ])),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Semantics(
                        header: true,
                        child: Text('Recording mode',
                            style: theme.textTheme.titleLarge)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Choose how you want to record your activity.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.lg),
                    _RecordingModeOption(
                      title: 'Plan a route',
                      description:
                          'Generate a route based on your target distance.',
                      icon: Icons.route_outlined,
                      selected: _mode == _RecordingMode.planRoute,
                      onTap: _isNavigating
                          ? null
                          : () => setState(() {
                                _mode = _RecordingMode.planRoute;
                                _navigationError = null;
                              }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RecordingModeOption(
                      title: 'Free recording',
                      description:
                          'Record your activity without a predefined route.',
                      icon: Icons.my_location_outlined,
                      selected: _mode == _RecordingMode.freeRecording,
                      onTap: _isNavigating
                          ? null
                          : () => setState(() {
                                _mode = _RecordingMode.freeRecording;
                                _navigationError = null;
                              }),
                    ),
                    if (_navigationError != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                          liveRegion: true,
                          child: KaripaFeedback(
                              title: 'Unable to continue',
                              message: _navigationError!,
                              kind: FeedbackKind.error)),
                    ],
                  ]),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(margin, AppSpacing.md, margin, AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
              child: SizedBox(
                  width: double.infinity,
                  child: KaripaButton(
                    label: _mode == _RecordingMode.planRoute
                        ? 'Continue to Route Planning'
                        : 'Start Free Recording',
                    icon: _mode == _RecordingMode.planRoute
                        ? Icons.arrow_forward
                        : Icons.play_arrow,
                    isLoading: _isNavigating,
                    onPressed: _isNavigating ? null : _continue,
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RecordingModeOption extends StatelessWidget {
  const _RecordingModeOption(
      {required this.title,
      required this.description,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant));
    return Semantics(
      label: '$title. $description',
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
          child: Material(
        color: selected
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.08), scheme.surface)
            : scheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: scheme.onSurface),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(description,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ])),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: scheme.onSurface),
            ]),
          ),
        ),
      )),
    );
  }
}
