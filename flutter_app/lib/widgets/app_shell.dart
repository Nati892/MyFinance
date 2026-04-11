import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/services/apk_service.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/locale_service.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentPath;

  const AppShell({super.key, required this.child, required this.currentPath});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _showHouseholdDropdown = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // APK download progress state
  bool _isDownloading = false;
  final _downloadProgress = ValueNotifier<(int, int)>((0, 0)); // (received, total)

  @override
  void initState() {
    super.initState();
    // Check for APK update on startup for developer users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authServiceProvider).currentUser;
      if (user?.isDeveloper == true) {
        _checkAndPromptUpdate(context);
      }
    });
  }

  static const _darkBlue1 = Color(0xFF141E30);
  static const _darkBlue2 = Color(0xFF1565C0);
  static const _activeColor = Color(0xFF667EEA);


  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final householdSvc = ref.watch(householdServiceProvider);
    final user = auth.currentUser;
    final selectedHousehold = householdSvc.selected;
    final hasMultiple = householdSvc.households.length > 1;
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      _TabItem(path: '/assets',       icon: Icons.account_balance, label: l10n.navAssets),
      _TabItem(path: '/budget',       icon: Icons.pie_chart,        label: l10n.navBudget),
      _TabItem(path: '/transactions', icon: Icons.swap_horiz,       label: l10n.navTransactions),
      _TabItem(path: '/statistics',   icon: Icons.bar_chart,        label: l10n.navStatistics),
      _TabItem(path: '/board',        icon: Icons.dashboard,        label: l10n.navBoard),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F8FC),
      endDrawer: _AppSidePanel(
        user: user,
        onLanguageToggle: () => ref.read(localeProvider.notifier).toggle(),
        onSignOut: () => ref.read(authServiceProvider).signOut(),
      ),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_darkBlue1, _darkBlue2],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Brand
                      Text(
                        l10n.headerBrand,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      // Household selector
                      _buildHouseholdSelector(
                          householdSvc, selectedHousehold, hasMultiple),
                      const Spacer(),
                      // Developer update button + profile icon
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user?.isDeveloper == true)
                            GestureDetector(
                              onLongPress: () => _isDownloading
                                  ? _showDownloadProgress(context)
                                  : _forceDownload(context),
                              child: IconButton(
                                icon: _isDownloading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.system_update_alt, size: 20),
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                tooltip: null,
                                onPressed: () => _isDownloading
                                    ? _showDownloadProgress(context)
                                    : _checkAndPromptUpdate(context),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.person, size: 22),
                            color: Colors.white,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Page content ──────────────────────────────────────────────────
          Expanded(child: widget.child),
        ],
      ),
      // ── Bottom nav ────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: tabs.map((tab) => _buildTab(tab)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkAndPromptUpdate(BuildContext context) async {
    final apkSvc = ref.read(apkServiceProvider);
    final info = await apkSvc.checkForUpdate();

    if (!context.mounted) return;

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check for updates')),
      );
      return;
    }

    if (!info.isUpdateAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are on the latest version (${info.latestVersion})'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content:
            Text('Version ${info.latestVersion} is available. Download now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    _downloadUpdate(context, info.downloadUrl);
  }

  Future<void> _forceDownload(BuildContext context) async {
    final apkSvc = ref.read(apkServiceProvider);
    final info = await apkSvc.checkForUpdate();
    if (!context.mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach server')),
      );
      return;
    }
    _downloadUpdate(context, info.downloadUrl);
  }

  Future<void> _downloadUpdate(BuildContext context, String url) async {
    final apkSvc = ref.read(apkServiceProvider);

    setState(() {
      _isDownloading = true;
    });
    _downloadProgress.value = (0, 0);

    try {
      await apkSvc.downloadAndInstall(
        url,
        onProgress: (received, total) {
          if (mounted) _downloadProgress.value = (received, total);
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showDownloadProgress(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadProgressSheet(progress: _downloadProgress),
    );
  }

  Widget _buildTab(_TabItem tab) {
    final isActive = widget.currentPath == tab.path;
    final color = isActive ? _activeColor : const Color(0xFFAAAAAA);
    return Expanded(
      child: InkWell(
        onTap: () => context.go(tab.path),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdSelector(
    HouseholdService svc,
    dynamic selected,
    bool hasMultiple,
  ) {
    return GestureDetector(
      onTap: hasMultiple
          ? () => setState(() =>
              _showHouseholdDropdown = !_showHouseholdDropdown)
          : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected?.name ?? '…',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasMultiple) ...[
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showHouseholdDropdown ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 16),
                ),
              ],
            ],
          ),
          if (_showHouseholdDropdown && hasMultiple)
            Positioned(
              top: 28,
              left: -60,
              child: _buildDropdown(svc),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(HouseholdService svc) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 160),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: svc.households.map((h) {
            final isSelected = h.householdId == svc.selected?.householdId;
            return InkWell(
              onTap: () {
                svc.selectHousehold(h);
                setState(() => _showHouseholdDropdown = false);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        h.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? const Color(0xFF667EEA)
                              : const Color(0xFF1A1A2E),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        h.role,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF888888)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Side panel drawer ────────────────────────────────────────────────────────

class _AppSidePanel extends ConsumerWidget {
  final dynamic user;
  final VoidCallback onLanguageToggle;
  final VoidCallback onSignOut;

  const _AppSidePanel({
    required this.user,
    required this.onLanguageToggle,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHe = ref.watch(localeProvider).languageCode == 'he';
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth.clamp(0.0, 300.0);

    return Drawer(
      width: panelWidth,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF141E30), Color(0xFF1565C0)],
              ),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user?.username ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Menu items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Language
                ListTile(
                  leading: const Icon(Icons.language, color: Color(0xFF667EEA)),
                  title: Text(
                    isHe ? 'Switch to English' : 'עבור לעברית',
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onLanguageToggle();
                  },
                ),

                // Settings
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: Color(0xFF667EEA)),
                  title: Text(l10n.drawerSettings, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),

                // Sign out
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF888888)),
                  title: Text(l10n.drawerSignOut, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    onSignOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final String label;
  const _TabItem({required this.path, required this.icon, required this.label});
}

// ─── Download progress bottom sheet ──────────────────────────────────────────

class _DownloadProgressSheet extends StatelessWidget {
  final ValueNotifier<(int, int)> progress;

  const _DownloadProgressSheet({required this.progress});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ValueListenableBuilder<(int, int)>(
        valueListenable: progress,
        builder: (_, value, __) {
          final received = value.$1;
          final total = value.$2;
          final fraction = (total > 0) ? (received / total).clamp(0.0, 1.0) : 0.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.system_update_alt,
                      size: 18, color: Color(0xFF667EEA)),
                  const SizedBox(width: 8),
                  const Text(
                    'Downloading update',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(fraction * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF667EEA),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction > 0 ? fraction : null,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EAF6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF667EEA),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                total > 0
                    ? '${_formatBytes(received)} of ${_formatBytes(total)}'
                    : 'Starting download…',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
