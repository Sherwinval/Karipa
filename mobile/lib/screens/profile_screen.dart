import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/design_tokens.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/api_service.dart';
import '../services/unit_preferences.dart';
import '../widgets/main_tab_scope.dart';

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
  final _imagePicker = ImagePicker();
  Uint8List? _profilePhotoBytes;
  bool _photoSaving = false;
  Timer? _profileSyncTimer;
  bool _profileRefreshInFlight = false;

  String _formatMeasurement(double? value, {required int decimals}) {
    if (value == null) return '';
    final fixed = value.toStringAsFixed(decimals);
    if (fixed.contains('.')) {
      final trimmed =
          fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
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

  Future<void> _editProfileName(AuthService authService) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileNameDialog(
        initialName: authService.name ?? '',
        onSave: authService.updateProfileName,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name updated.')),
      );
    }
  }

  Future<void> _changeProfilePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 2500000) {
        throw Exception('Choose a photo smaller than 2.5 MB.');
      }

      final extension = image.name.split('.').last.toLowerCase();
      final mimeType = image.mimeType ??
          switch (extension) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };
      if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
        throw Exception('Choose a JPEG, PNG, or WebP image.');
      }
      final photoData = 'data:$mimeType;base64,${base64Encode(bytes)}';

      setState(() => _photoSaving = true);
      final profile = await ApiService.updateProfilePhoto(photoData);
      final savedPhotoData = profile['photoData'];
      if (savedPhotoData is! String || !savedPhotoData.contains(',')) {
        throw Exception('The server returned an invalid profile photo.');
      }
      if (!mounted) return;
      setState(() {
        _profilePhotoBytes = base64Decode(savedPhotoData.split(',').last);
        _photoSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _photoSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final units = Provider.of<UnitPreferences>(context);
    if (_renderedUnitSystem != units.system) {
      _syncControllersToDraft(units);
    }
    final active = MainTabScope.maybeOf(context)?.isActive(3) ?? true;
    if (!active) {
      _profileSyncTimer?.cancel();
      _profileSyncTimer = null;
      return;
    }
    if (!_profileLoadStarted &&
        Provider.of<AuthService>(context).isAuthenticated) {
      _profileLoadStarted = true;
      _loadMeasurements();
    }
    if (Provider.of<AuthService>(context).isAuthenticated) {
      _profileSyncTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refreshProfileFromServer(),
      );
    }
  }

  Future<void> _refreshProfileFromServer() async {
    if (!mounted ||
        _profileRefreshInFlight ||
        _profileLoading ||
        _profileSaving ||
        _photoSaving ||
        _isEditingMeasurements) {
      return;
    }

    _profileRefreshInFlight = true;
    try {
      final profile = await ApiService.refreshProfileIfChanged();
      if (profile == null || !mounted) return;

      final name = profile['name'];
      if (name is String && name.trim().isNotEmpty) {
        await context.read<AuthService>().syncProfileNameFromServer(name);
      }
      if (!mounted) return;

      final height = profile['heightCm']?.toString() ?? '';
      final weight = profile['weightKg']?.toString() ?? '';
      final photoData = profile['photoData'];
      final photoBytes = photoData is String && photoData.contains(',')
          ? base64Decode(photoData.split(',').last)
          : null;
      _savedHeight = height;
      _savedWeight = weight;
      _draftHeightCm = double.tryParse(height);
      _draftWeightKg = double.tryParse(weight);
      _syncControllersToDraft(context.read<UnitPreferences>());
      setState(() {
        _profilePhotoBytes = photoBytes;
        _profileLoaded = true;
        _profileError = null;
      });
    } catch (error) {
      debugPrint('Could not sync profile updates: $error');
    } finally {
      _profileRefreshInFlight = false;
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
      final photoData = profile['photoData'];
      if (photoData is String && photoData.contains(',')) {
        _profilePhotoBytes = base64Decode(photoData.split(',').last);
      }
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
    _profileSyncTimer?.cancel();
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

    final pageColor = theme.brightness == Brightness.light
        ? Color.alphaBlend(colorScheme.surfaceContainer.withValues(alpha: 0.24),
            colorScheme.surface)
        : colorScheme.surface;
    final headerInset =
        AppSpacing.pageMargin(MediaQuery.sizeOf(context).width) - AppSpacing.sm;

    return MainSection(
      backgroundColor: pageColor,
      appBar: AppBar(
        automaticallyImplyLeading: MainTabScope.maybeOf(context) == null,
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: pageColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: EdgeInsets.symmetric(horizontal: headerInset),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      button: authService.isAuthenticated,
                      label: _photoSaving
                          ? 'Saving profile photo'
                          : 'Change profile photo',
                      child: Tooltip(
                          message: 'Change profile photo',
                          child: InkWell(
                            onTap: authService.isAuthenticated && !_photoSaving
                                ? _changeProfilePhoto
                                : null,
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Stack(children: [
                                  Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainer,
                                          shape: BoxShape.circle,
                                          image: _profilePhotoBytes == null
                                              ? null
                                              : DecorationImage(
                                                  image: MemoryImage(
                                                      _profilePhotoBytes!),
                                                  fit: BoxFit.cover)),
                                      child: _profilePhotoBytes == null
                                          ? Icon(Icons.person_outline,
                                              size: 36,
                                              color:
                                                  colorScheme.onSurfaceVariant)
                                          : null),
                                  if (authService.isAuthenticated)
                                    Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                colorScheme.surfaceContainer,
                                            child: _photoSaving
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2))
                                                : Icon(
                                                    Icons.camera_alt_outlined,
                                                    size: 16,
                                                    color: colorScheme
                                                        .onSurface))),
                                ])),
                          )),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              authService.isGuest
                                  ? 'Guest'
                                  : (authService.name ?? 'Karipa Athlete'),
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                              authService.isAuthenticated
                                  ? 'Signed in'
                                  : 'Guest account',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                          if (authService.isAuthenticated)
                            TextButton(
                                onPressed: () => _editProfileName(authService),
                                child: const Text('Edit name')),
                          if (authService.isGuest)
                            TextButton(
                                onPressed: () {
                                  authService.logout();
                                  Navigator.pushNamedAndRemoveUntil(
                                      context, '/login', (route) => false);
                                },
                                child: const Text('Sign In')),
                        ])),
                  ],
                )),
            const SizedBox(height: AppSpacing.xl),

            _ProfileSurface(
                child: _buildMeasurementsSection(
                    authService, theme, colorScheme, units)),
            const SizedBox(height: 20),
            _ProfileSurface(
                child: _buildUnitSystemSection(units, theme, colorScheme)),
            const SizedBox(height: 20),

            _ProfileSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text('Activity & account',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: const Text('Activity History'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final scope = MainTabScope.maybeOf(context);
                        if (scope != null) {
                          scope.select(2);
                        } else {
                          Navigator.pushNamed(context, '/activity_history');
                        }
                      }),
                  Divider(
                      height: 1,
                      indent: AppSizes.icon + AppSpacing.xxl,
                      color: colorScheme.onSurface.withValues(alpha: 0.12)),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Account status'),
                      subtitle: Text(authService.isAuthenticated
                          ? 'Signed in'
                          : 'Guest session')),
                  Divider(
                      height: 1,
                      indent: AppSizes.icon + AppSpacing.xxl,
                      color: colorScheme.onSurface.withValues(alpha: 0.12)),
                  const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline),
                      title: Text('About Karipa'),
                      subtitle: Text('v1.0.0')),
                ])),
            const SizedBox(height: 24),

            // Logout / Exit Button
            Padding(
                padding: EdgeInsets.symmetric(horizontal: headerInset),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(authService.isGuest
                            ? 'Exit Guest Mode?'
                            : 'Log Out?'),
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
                  style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                      side: BorderSide(color: colorScheme.outlineVariant)),
                  icon: const Icon(Icons.logout, size: 20),
                  label: Text(
                    authService.isGuest ? 'Exit Guest Mode' : 'Sign Out',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                )),
          ]),
        ),
      ),
    );
  }

  Widget _buildUnitSystemSection(
    UnitPreferences units,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Preferences', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      Text('Units', style: theme.textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Text('${units.distanceUnit} · ${units.heightUnit} · ${units.weightUnit}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant)),
      const SizedBox(height: AppSpacing.md),
      LayoutBuilder(builder: (context, constraints) {
        final vertical = constraints.maxWidth < 340 &&
            MediaQuery.textScalerOf(context).scale(14) > 18;
        return SegmentedButton<UnitSystem>(
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
          direction: vertical ? Axis.vertical : Axis.horizontal,
          segments: const [
            ButtonSegment(value: UnitSystem.metric, label: Text('Metric')),
            ButtonSegment(value: UnitSystem.imperial, label: Text('Imperial')),
          ],
          selected: {units.system},
          onSelectionChanged: (selection) => _changeUnitSystem(selection.first),
        );
      }),
      const _ProfileDisclosure(
          title: 'About display units',
          details:
              'Choose how distances and profile measurements are displayed. Saved values remain unchanged. Imperial height is shown in decimal feet.'),
      Consumer<ThemeService>(
          builder: (context, themeService, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: themeService.isDarkMode,
              onChanged: themeService.toggleTheme)),
    ]);
  }

  Widget _buildMeasurementsSection(
    AuthService authService,
    ThemeData theme,
    ColorScheme colorScheme,
    UnitPreferences units,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Body measurements', style: theme.textTheme.titleMedium),
                Text('Optional',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ]),
              if (authService.isAuthenticated &&
                  _profileLoaded &&
                  !_isEditingMeasurements)
                TextButton(
                    onPressed: _profileSaving
                        ? null
                        : () => setState(() {
                              _profileError = null;
                              _isEditingMeasurements = true;
                            }),
                    child: const Text('Edit')),
            ]),
        const SizedBox(height: AppSpacing.md),
        if (!authService.isAuthenticated) ...[
          const _MeasurementSummary(height: 'Not set', weight: 'Not set'),
          const SizedBox(height: 12),
          Text(
            'Sign in to save measurements to your account. You can still plan routes and track activities without them.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
          if (!_isEditingMeasurements)
            _MeasurementSummary(
                height: _heightController.text.isEmpty
                    ? 'Not set'
                    : '${_heightController.text} ${units.heightUnit}',
                weight: _weightController.text.isEmpty
                    ? 'Not set'
                    : '${_weightController.text} ${units.weightUnit}')
          else
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
                          : context.read<UnitPreferences>().heightToCm(parsed);
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
                          : context.read<UnitPreferences>().weightToKg(parsed);
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
          if (_isEditingMeasurements) ...[
            LayoutBuilder(builder: (context, constraints) {
              final cancel = OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                  side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.35)),
                ),
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
              );
              final save = FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                  elevation: 0,
                ),
                onPressed: _profileSaving ? null : _saveMeasurements,
                child: _profileSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              );
              if (constraints.maxWidth <
                  240 * MediaQuery.textScalerOf(context).scale(14) / 14) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cancel,
                    const SizedBox(height: AppSpacing.sm),
                    save,
                  ],
                );
              }
              return Row(children: [
                Expanded(child: cancel),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: save),
              ]);
            }),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    textStyle: theme.textTheme.labelMedium,
                    minimumSize:
                        const Size(AppSizes.touchTarget, AppSizes.touchTarget),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  ),
                  onPressed: _profileSaving ? null : _clearMeasurements,
                  child: const Text('Clear values')),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.sm),
        Text('Weight supports eligible calorie estimates.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const _ProfileDisclosure(
            title: 'How measurements are used',
            details:
                'These measurements are optional. Weight supports provisional gross session calorie estimates using the published MET examples; adviser review is pending. Height is not used in the current calorie equation. Route planning and activity tracking work without them.'),
      ],
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

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: theme.brightness == Brightness.light
          ? scheme.surface
          : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

class _MeasurementSummary extends StatelessWidget {
  const _MeasurementSummary({required this.height, required this.weight});
  final String height;
  final String weight;
  @override
  Widget build(BuildContext context) {
    Widget metric(String label, String value) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 340 &&
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          metric('Height', height),
          const SizedBox(height: AppSpacing.md),
          metric('Weight', weight)
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: metric('Height', height)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: metric('Weight', weight))
      ]);
    });
  }
}

class _ProfileDisclosure extends StatelessWidget {
  const _ProfileDisclosure({required this.title, required this.details});
  final String title;
  final String details;
  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        shape: const Border(),
        collapsedShape: const Border(),
        minTileHeight: AppSizes.touchTarget,
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        title: Text(title, style: Theme.of(context).textTheme.bodySmall),
        children: [
          Text(details,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
        ],
      );
}

class _EditProfileNameDialog extends StatefulWidget {
  const _EditProfileNameDialog({
    required this.initialName,
    required this.onSave,
  });

  final String initialName;
  final Future<void> Function(String name) onSave;

  @override
  State<_EditProfileNameDialog> createState() => _EditProfileNameDialogState();
}

class _EditProfileNameDialogState extends State<_EditProfileNameDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(name);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
