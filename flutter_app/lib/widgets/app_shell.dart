import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:household/l10n/app_localizations.dart';
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
      _TabItem(path: '/home',         icon: Icons.bar_chart,        label: l10n.navStatistics),
      _TabItem(path: '/board',        icon: Icons.dashboard,        label: l10n.navBoard),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
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
                      // User menu
                      _buildUserMenu(ref, user, l10n),
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

  Widget _buildUserMenu(WidgetRef ref, dynamic user, AppLocalizations l10n) {
    return Builder(
      builder: (btnContext) => IconButton(
        icon: const Icon(Icons.person, size: 22),
        color: Colors.white,
        onPressed: () => _openUserMenu(btnContext, ref, user, l10n),
      ),
    );
  }

  void _openUserMenu(BuildContext btnContext, WidgetRef ref, dynamic user, AppLocalizations l10n) {
    final isHe = ref.read(localeProvider).languageCode == 'he';
    final button = btnContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(btnContext).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: btnContext,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 180),
      items: [
        if (user != null)
          PopupMenuItem<String>(
            enabled: false,
            height: 42,
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Color(0xFF888888)),
                const SizedBox(width: 8),
                Text(user.username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'language',
          height: 42,
          child: Row(
            children: [
              const Icon(Icons.language, size: 16, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Text(isHe ? 'English' : 'עברית', style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          height: 42,
          child: Row(
            children: [
              const Icon(Icons.logout, size: 16, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Text(l10n.headerSignOut, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'language') {
        ref.read(localeProvider.notifier).toggle();
      } else if (value == 'logout') {
        ref.read(authServiceProvider).signOut();
      }
    });
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

class _TabItem {
  final String path;
  final IconData icon;
  final String label;
  const _TabItem({required this.path, required this.icon, required this.label});
}
