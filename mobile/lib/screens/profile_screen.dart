import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
}
