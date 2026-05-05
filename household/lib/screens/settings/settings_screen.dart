import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/locale_service.dart';
import 'package:household/services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fontScale = ref.watch(fontScaleProvider);
    final locale = ref.watch(localeProvider);

    const presets = [
      _FontPreset(label: 'S', scale: 0.85),
      _FontPreset(label: 'M', scale: null),
      _FontPreset(label: 'L', scale: 1.2),
      _FontPreset(label: 'XL', scale: 1.4),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Text size section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              l10n.settingsTextSize,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l10n.settingsTextSizeHint,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
          Row(
            children: presets.map((p) {
              final isSelected = fontScale == p.scale;
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(fontScaleProvider.notifier).setScale(p.scale),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF667EEA)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? null
                          : Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      p.label,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: p.scale != null ? 13 * (p.scale ?? 1.0) : 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF555555),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              l10n.settingsTextSizePreview,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          // Language section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              l10n.settingsLanguage,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l10n.settingsLanguageHint,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Text(
                  'English / עברית',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Switch(
                  value: locale.languageCode == 'he',
                  onChanged: (_) =>
                      ref.read(localeProvider.notifier).toggle(),
                  activeThumbColor: const Color(0xFF667EEA),
                  activeTrackColor: const Color(0xFF667EEA).withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Financial month section
          _FinancialMonthSection(),
          const SizedBox(height: 24),
          // Expense Schedules section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              l10n.scheduleSettingsSection,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/app/schedules'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFF1976D2), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.scheduleSettingsTitle,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.scheduleSettingsSubtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFFBBBBBB), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // About section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              l10n.settingsAbout,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsAppName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.settingsVersion,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontPreset {
  final String label;
  final double? scale;
  const _FontPreset({required this.label, required this.scale});
}

class _FinancialMonthSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(householdServiceProvider);
    final startDay = household.currentStartDay;
    final canEdit = household.selected?.role == 'admin';

    final rangeText = startDay == 1
        ? l10n.settingsFinancialMonthCalendarRange
        : l10n.settingsFinancialMonthRange(
            (startDay - 1).toString(), // end
            startDay.toString(),       // start
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            l10n.settingsFinancialMonth,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            l10n.settingsFinancialMonthHint,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
        GestureDetector(
          onTap: canEdit ? () => _openPicker(context, ref, startDay) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month,
                    color: Color(0xFF667EEA), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.settingsFinancialMonthDayLabel} $startDay',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rangeText,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  const Icon(Icons.chevron_right,
                      color: Color(0xFFBBBBBB), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(
      BuildContext context, WidgetRef ref, int currentDay) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DayPickerSheet(
        title: l10n.settingsFinancialMonthPickerTitle,
        currentDay: currentDay,
      ),
    );
    if (picked == null || picked == currentDay) return;
    try {
      await ref
          .read(householdServiceProvider)
          .updateFinancialMonthStartDay(picked);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsFinancialMonthSaveError)),
      );
    }
  }
}

class _DayPickerSheet extends StatelessWidget {
  final String title;
  final int currentDay;
  const _DayPickerSheet({required this.title, required this.currentDay});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: List.generate(28, (i) {
                final day = i + 1;
                final selected = day == currentDay;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF667EEA)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? null
                          : Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF555555),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
