import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/api_service.dart';
import '../services/unit_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _profileFormKey = GlobalKey<FormState>();
  bool _profileLoadStarted = false;
  bool _profileLoading = false;
  bool _profileLoaded = false;
  bool _profileSaving = false;
  bool _isEditingMeasurements = false;
  String _savedHeight = '';
  String _savedWeight = '';
  double? _draftHeightCm;
  double? _draftWeightKg;
  UnitSystem? _renderedUnitSystem;
  String? _profileError;

  String _formatMeasurement(double? value, {required int decimals}) {
    if (value == null) return '';
    final fixed = value.toStringAsFixed(decimals);
    if (fixed.contains('.')) {
      final trimmed = fixed
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      return trimmed;
    }
    return fixed;
  }

  void _syncControllersToDraft(UnitPreferences units) {
    _heightController.text = _formatMeasurement(
      _draftHeightCm == null ? null : units.heightFromCm(_draftHeightCm!),
      decimals: units.isImperial ? 2 : 1,
    );
    _weightController.text = _formatMeasurement(
      _draftWeightKg == null ? null : units.weightFromKg(_draftWeightKg!),
      decimals: 1,
    );
    _renderedUnitSystem = units.system;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final units = Provider.of<UnitPreferences>(context);
    if (_renderedUnitSystem != units.system) {
      _syncControllersToDraft(units);
    }
    if (!_profileLoadStarted &&
        Provider.of<AuthService>(context).isAuthenticated) {
      _profileLoadStarted = true;
      _loadMeasurements();
    }
  }

  Future<void> _loadMeasurements() async {
    setState(() => _profileLoading = true);
    try {
      final profile = await ApiService.getProfile();
      if (!mounted) return;
      _savedHeight = profile['heightCm']?.toString() ?? '';
      _savedWeight = profile['weightKg']?.toString() ?? '';
      _draftHeightCm = double.tryParse(_savedHeight);
      _draftWeightKg = double.tryParse(_savedWeight);
      if (mounted) {
        final units = context.read<UnitPreferences>();
        _syncControllersToDraft(units);
      }
      setState(() {
        _profileError = null;
        _profileLoaded = true;
        _profileLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = error.toString().replaceFirst('Exception: ', '');
        _profileLoaded = false;
        _profileLoading = false;
      });
    }
  }

  Future<void> _saveMeasurements() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() {
      _profileSaving = true;
      _profileError = null;
    });
    try {
      final saved = await ApiService.updateProfile(
        heightCm: _draftHeightCm,
        weightKg: _draftWeightKg,
      );
      if (!mounted) return;
      _savedHeight = saved['heightCm']?.toString() ?? '';
      _savedWeight = saved['weightKg']?.toString() ?? '';
      _draftHeightCm = double.tryParse(_savedHeight);
      _draftWeightKg = double.tryParse(_savedWeight);
      if (mounted) {
        final units = context.read<UnitPreferences>();
        _syncControllersToDraft(units);
      }
      setState(() {
        _profileSaving = false;
        _isEditingMeasurements = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileSaving = false;
        _profileError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _clearMeasurements() async {
    setState(() {
      _profileSaving = true;
      _profileError = null;
    });
    try {
      await ApiService.updateProfile(heightCm: null, weightKg: null);
      if (!mounted) return;
      _savedHeight = '';
      _savedWeight = '';
      _draftHeightCm = null;
      _draftWeightKg = null;
      _heightController.clear();
      _weightController.clear();
      setState(() {
        _profileSaving = false;
        _isEditingMeasurements = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileSaving = false;
        _profileError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _changeUnitSystem(UnitSystem system) async {
    try {
      await context.read<UnitPreferences>().setSystem(system);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save measurement units: $error')),
      );
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = context.watch<UnitPreferences>();
    if (_renderedUnitSystem != units.system) {
      _syncControllersToDraft(units);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // User Avatar & Name Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                      color: KaripaPalette.midnight.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [KaripaPalette.coral, KaripaPalette.coral],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        size: 44, color: KaripaPalette.midnight),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authService.isGuest
                        ? 'Guest Runner'
                        : (authService.name ?? 'Karipa Athlete'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authService.isAuthenticated
                        ? 'Verified Runner Account'
                        : 'Guest Account',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (authService.isGuest) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guest Mode Active',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign in to sync your fitness activities and save routes.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              authService.logout();
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/login', (route) => false);
                            },
                            child: Text('Sign In',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildMeasurementsSection(authService, theme, colorScheme, units),
            const SizedBox(height: 20),
            _buildUnitSystemSection(units, theme, colorScheme),
            const SizedBox(height: 20),

            // Actions List
            Ink(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.history,
                        color: Theme.of(context).colorScheme.onSurface),
                    title: const Text('Activity History',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface),
                    onTap: () =>
                        Navigator.pushNamed(context, '/activity_history'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.security,
                        color: Theme.of(context).colorScheme.onSurface),
                    title: const Text('Account Security',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      authService.isAuthenticated
                          ? 'JWT Authenticated & Protected'
                          : 'Unauthenticated Guest Session',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      authService.isAuthenticated
                          ? Icons.check_circle
                          : Icons.shield_outlined,
                      color: authService.isAuthenticated
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                  const Divider(height: 1),
                  Consumer<ThemeService>(
                    builder: (context, themeService, _) {
                      return SwitchListTile(
                        secondary: Icon(Icons.dark_mode,
                            color: Theme.of(context).colorScheme.onSurface),
                        title: const Text('Dark Mode',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        value: themeService.isDarkMode,
                        onChanged: (value) {
                          themeService.toggleTheme(value);
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurface),
                    title: const Text('About Karipa',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('v1.0.0 • AI-Driven Routing Engine',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout / Exit Button
            ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                        authService.isGuest ? 'Exit Guest Mode?' : 'Log Out?'),
                    content: Text(authService.isGuest
                        ? 'Are you sure you want to exit guest mode and return to sign in?'
                        : 'Are you sure you want to sign out of Karipa?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: KaripaPalette.coral,
                            foregroundColor: KaripaPalette.midnight),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(authService.isGuest
                            ? 'Exit Guest Mode'
                            : 'Log Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: KaripaPalette.coral,
                foregroundColor: KaripaPalette.midnight,
                elevation: 0,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: Text(
                authService.isGuest ? 'Exit Guest Mode' : 'Sign Out',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSystemSection(
    UnitPreferences units,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Measurement Units',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(
            'Choose how distances and profile measurements are displayed. Saved values remain unchanged.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SegmentedButton<UnitSystem>(
            segments: const [
              ButtonSegment(
                  value: UnitSystem.metric,
                  label: Text('Metric'),
                  icon: Icon(Icons.straighten)),
              ButtonSegment(
                  value: UnitSystem.imperial,
                  label: Text('Imperial'),
                  icon: Icon(Icons.swap_horiz)),
            ],
            selected: {units.system},
            onSelectionChanged: (selection) =>
                _changeUnitSystem(selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            units.isImperial
                ? 'Distance: miles • Height: decimal feet • Weight: pounds'
                : 'Distance: kilometers • Height: centimeters • Weight: kilograms',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsSection(
    AuthService authService,
    ThemeData theme,
    ColorScheme colorScheme,
    UnitPreferences units,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Optional Measurements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              )),
          const SizedBox(height: 8),
          Text(
            'These measurements are optional. Weight supports provisional gross session calorie estimates using the published MET examples; adviser review is pending. Height is not used in the current calorie equation. Route planning and activity tracking work without them.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          if (!authService.isAuthenticated) ...[
            const SizedBox(height: 12),
            Text(
              'Sign in to save measurements to your account. You can still plan routes and track activities without them.',
              style:
                  TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ] else if (_profileLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (!_profileLoaded) ...[
            if (_profileError != null) ...[
              const SizedBox(height: 10),
              Text(_profileError!,
                  style: TextStyle(color: colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _profileLoading ? null : _loadMeasurements,
              child: const Text('Retry loading measurements'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Form(
              key: _profileFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _heightController,
                    enabled: _isEditingMeasurements && !_profileSaving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final parsed = double.tryParse(value.trim());
                      _draftHeightCm = parsed == null
                          ? null
                          : context
                              .read<UnitPreferences>()
                              .heightToCm(parsed);
                    },
                    decoration: InputDecoration(
                      labelText: 'Height (${units.heightUnit})',
                      suffixText: units.heightUnit,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => _validateMeasurement(
                      value,
                      unit: units.heightUnit,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weightController,
                    enabled: _isEditingMeasurements && !_profileSaving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final parsed = double.tryParse(value.trim());
                      _draftWeightKg = parsed == null
                          ? null
                          : context
                              .read<UnitPreferences>()
                              .weightToKg(parsed);
                    },
                    decoration: InputDecoration(
                      labelText: 'Weight (${units.weightUnit})',
                      suffixText: units.weightUnit,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => _validateMeasurement(
                      value,
                      unit: units.weightUnit,
                    ),
                  ),
                ],
              ),
            ),
            if (_profileError != null) ...[
              const SizedBox(height: 10),
              Text(_profileError!,
                  style: TextStyle(color: colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            if (_isEditingMeasurements)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _profileSaving
                          ? null
                          : () {
                              _draftHeightCm = double.tryParse(_savedHeight);
                              _draftWeightKg = double.tryParse(_savedWeight);
                              final units = context.read<UnitPreferences>();
                              _syncControllersToDraft(units);
                              setState(() {
                                _profileError = null;
                                _isEditingMeasurements = false;
                              });
                            },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _profileSaving ? null : _saveMeasurements,
                      child: _profileSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _profileSaving
                          ? null
                          : () => setState(() {
                                _profileError = null;
                                _isEditingMeasurements = true;
                              }),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _profileSaving ? null : _clearMeasurements,
                      child: const Text('Clear values'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String? _validateMeasurement(
    String? value, {
    required String unit,
  }) {
    if (!_isEditingMeasurements || value == null || value.trim().isEmpty) {
      return null;
    }
    final measurement = double.tryParse(value.trim());
    if (measurement == null || !measurement.isFinite) {
      return 'Enter a valid number in $unit.';
    }
    if (measurement <= 0) {
      return 'Enter a positive value in $unit.';
    }
    return null;
  }
}
