import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocking_service.dart';
import '../models/app_blocking_model.dart';

class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({super.key});

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _showOnlyBlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppBlockingService>().init();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AppBlockingService>();
    final theme = Theme.of(context);

    // Filter installed apps by search query
    final allApps = svc.installedApps;
    final filtered = allApps.where((app) {
      final matchesQuery = _query.isEmpty ||
          app.appName.toLowerCase().contains(_query.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_query.toLowerCase());
      final matchesFilter = !_showOnlyBlocked || svc.isBlocked(app.packageName);
      return matchesQuery && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: _buildAppBar(theme, svc),
      body: svc.isLoading && allApps.isEmpty
          ? _buildLoadingState()
          : allApps.isEmpty
              ? _buildNoAppsState(theme)
              : Column(
                  children: [
                    _buildSearchAndFilter(theme, svc),
                    _buildSessionBanner(svc, theme),
                    Expanded(child: _buildAppList(filtered, svc, theme)),
                  ],
                ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ThemeData theme, AppBlockingService svc) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A14),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blocked Apps',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            '${svc.blocklist.length} app${svc.blocklist.length == 1 ? "" : "s"} blocked',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      actions: [
        // Refresh
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
          onPressed: () => svc.fetchInstalledApps(),
          tooltip: 'Refresh apps',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white12),
      ),
    );
  }

  // ── Search & Filter ─────────────────────────────────────────────────────

  Widget _buildSearchAndFilter(ThemeData theme, AppBlockingService svc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12121E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter toggle
          GestureDetector(
            onTap: () => setState(() => _showOnlyBlocked = !_showOnlyBlocked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _showOnlyBlocked
                    ? const Color(0xFF7B61FF).withValues(alpha: 0.2)
                    : const Color(0xFF12121E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showOnlyBlocked
                      ? const Color(0xFF7B61FF)
                      : Colors.white12,
                ),
              ),
              child: Icon(
                Icons.filter_list_rounded,
                color: _showOnlyBlocked
                    ? const Color(0xFF7B61FF)
                    : Colors.white54,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Session Banner ──────────────────────────────────────────────────────

  Widget _buildSessionBanner(AppBlockingService svc, ThemeData theme) {
    if (!svc.sessionActive) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Focus Mode Active — blocked apps are locked',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => svc.stopSession(),
            child: const Text(
              'End',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App List ─────────────────────────────────────────────────────────────

  Widget _buildAppList(
      List<InstalledApp> apps, AppBlockingService svc, ThemeData theme) {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              _showOnlyBlocked
                  ? 'No blocked apps yet'
                  : 'No apps match "$_query"',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: apps.length,
      itemBuilder: (ctx, i) {
        final app = apps[i];
        final blocked = svc.isBlocked(app.packageName);
        return _AppTile(
          app: app,
          isBlocked: blocked,
          onToggle: (val) async {
            if (val) {
              await svc.addApp(app);
            } else {
              await svc.removeApp(app.packageName);
            }
          },
        );
      },
    );
  }

  // ── States ──────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF7B61FF)),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text('Loading installed apps...',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNoAppsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.android_rounded,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'No apps found',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Grant Usage Access permission to load your installed apps.',
              style: TextStyle(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Tile ─────────────────────────────────────────────────────────────────

class _AppTile extends StatelessWidget {
  final InstalledApp app;
  final bool isBlocked;
  final ValueChanged<bool> onToggle;

  const _AppTile({
    required this.app,
    required this.isBlocked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBlocked
              ? const Color(0xFFFF4757).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.07),
          width: 1.5,
        ),
        boxShadow: isBlocked
            ? [
                BoxShadow(
                  color: const Color(0xFFFF4757).withValues(alpha: 0.07),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        // App icon placeholder
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isBlocked
                ? const Color(0xFFFF4757).withValues(alpha: 0.12)
                : const Color(0xFF7B61FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isBlocked
                ? Icons.block_rounded
                : Icons.apps_rounded,
            color: isBlocked
                ? const Color(0xFFFF4757)
                : const Color(0xFF7B61FF),
            size: 22,
          ),
        ),
        title: Text(
          app.appName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          app.packageName,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Switch.adaptive(
          value: isBlocked,
          onChanged: onToggle,
          activeThumbColor: const Color(0xFFFF4757),
          activeTrackColor: const Color(0xFFFF4757).withValues(alpha: 0.3),
          inactiveTrackColor: Colors.white12,
          inactiveThumbColor: Colors.white38,
        ),
      ),
    );
  }
}
