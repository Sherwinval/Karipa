import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authService.isGuest ? 'Guest Runner' : (authService.name ?? 'PathCraft Athlete'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authService.isAuthenticated ? 'Verified Runner Account' : 'Guest Account',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  if (authService.isGuest) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF0D9488), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Guest Mode Active',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign in to sync your fitness activities and save routes.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              authService.logout();
                              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                            },
                            child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history, color: Color(0xFF0D9488)),
                    title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.pushNamed(context, '/activity_history'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security, color: Color(0xFF0D9488)),
                    title: const Text('Account Security', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      authService.isAuthenticated ? 'JWT Authenticated & Protected' : 'Unauthenticated Guest Session',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      authService.isAuthenticated ? Icons.check_circle : Icons.shield_outlined,
                      color: authService.isAuthenticated ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: Color(0xFF0D9488)),
                    title: Text('About PathCraft', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('v1.0.0 • AI-Driven Routing Engine', style: TextStyle(fontSize: 12)),
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
                    title: Text(authService.isGuest ? 'Exit Guest Mode?' : 'Log Out?'),
                    content: Text(authService.isGuest
                        ? 'Are you sure you want to exit guest mode and return to sign in?'
                        : 'Are you sure you want to sign out of PathCraft?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(authService.isGuest ? 'Exit Guest Mode' : 'Log Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: Text(
                authService.isGuest ? 'Exit Guest Mode' : 'Sign Out',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
