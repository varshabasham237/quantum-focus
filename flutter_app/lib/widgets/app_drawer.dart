import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Side Drawer — Dashboard navigation panel
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Drawer(
      backgroundColor: AppTheme.bgSecondary,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: AppTheme.gradientPrimary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      (auth.userName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  auth.userName ?? 'Student',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  auth.userEmail ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Menu Items
          _DrawerItem(
            icon: Icons.psychology_rounded,
            label: 'Focus Session',
            isSelected: true,
            onTap: () => Navigator.pop(context),
          ),
          _DrawerItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          _DrawerItem(
            icon: Icons.calendar_month_outlined,
            label: 'Study Planner',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/planner');
            },
          ),
          _DrawerItem(
            icon: Icons.event_note_rounded,
            label: 'Calendar & Deadlines',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/calendar');
            },
          ),
          _DrawerItem(
            icon: Icons.history_rounded,
            label: 'Session History',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to history
            },
          ),
          _DrawerItem(
            icon: Icons.insert_chart_outlined_rounded,
            label: 'Analysis & Reports',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/analysis');
            },
          ),
          _DrawerItem(
            icon: Icons.block_outlined,
            label: 'App Blocker',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to app blocker
            },
          ),
          _DrawerItem(
            icon: Icons.shield_moon_outlined,
            label: 'Adaptive Strictness',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/strictness');
            },
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to settings
            },
          ),

          const Spacer(),

          // Streak / Stats Mini Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentViolet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentViolet.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_fire_department, color: AppTheme.accentAmber, size: 28),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Streak', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Text('0 days', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Logout
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            textColor: AppTheme.accentRose,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.bgSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  content: const Text(
                    'Are you sure you want to logout? Your session will be securely terminated.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.accentRose.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Logout', style: TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                final auth = context.read<AuthService>();
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              }
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Individual drawer menu item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color? textColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? (isSelected ? AppTheme.accentViolet : AppTheme.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? AppTheme.accentViolet.withValues(alpha: 0.1) : Colors.transparent,
        onTap: onTap,
      ),
    );
  }
}
