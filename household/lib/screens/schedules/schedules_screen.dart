import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/expense_schedule.dart';
import 'package:household/screens/schedules/schedules_view_model.dart';
import 'package:household/utils/icon_helper.dart';
import 'package:household/widgets/expense_schedule_form_sheet.dart';

const _kScheduleColor = Color(0xFF1976D2); // blue accent for schedules

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(schedulesViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    if (vm.noHousehold) {
      return Scaffold(
        body: Center(child: Text(l10n.commonNoHousehold)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(l10n.schedulesScreenTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: _buildBody(context, vm),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_schedule',
        onPressed: () {
          vm.openAdd();
          _showFormSheet(context);
        },
        backgroundColor: _kScheduleColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SchedulesViewModel vm) {
    final l10n = AppLocalizations.of(context)!;

    if (vm.loadState == SchedulesLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.loadState == SchedulesLoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.scheduleLoadFailed,
                style: const TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: vm.load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }

    if (vm.schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              l10n.scheduleEmpty,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF555555)),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.scheduleEmptySub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.schedules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final schedule = vm.schedules[index];
        return _ScheduleCard(
          schedule: schedule,
          onTap: () {
            vm.openEdit(schedule);
            _showFormSheet(context);
          },
        );
      },
    );
  }

  void _showFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExpenseScheduleFormSheet(),
    );
  }
}

// ─── Schedule card ────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final ExpenseSchedule schedule;
  final VoidCallback onTap;

  const _ScheduleCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayShort = [
      l10n.scheduleDaySun, l10n.scheduleDayMon, l10n.scheduleDayTue,
      l10n.scheduleDayWed, l10n.scheduleDayThu, l10n.scheduleDayFri,
      l10n.scheduleDaySat,
    ];
    final cat = schedule.category;
    final catColor = cat?.color;
    final color = catColor != null
        ? Color(int.parse(catColor.replaceFirst('#', '0xFF')))
        : const Color(0xFF667EEA);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: schedule.isActive
                ? color.withValues(alpha:0.3)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Category icon
                if (cat != null && cat.icon != null)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconDataFromName(cat.icon),
                        size: 18, color: color),
                  ),
                if (cat != null && cat.icon != null) const SizedBox(width: 10),
                // Description + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.description,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: schedule.isActive
                              ? Colors.black87
                              : Colors.black38,
                        ),
                      ),
                      if (cat != null)
                        Text(
                          cat.name,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888888)),
                        ),
                    ],
                  ),
                ),
                // Amount (if set)
                if (schedule.amount != null)
                  Text(
                    '₪${schedule.amount!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: schedule.isActive
                          ? const Color(0xFFE53935)
                          : Colors.black38,
                    ),
                  ),
                // Active indicator
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: schedule.isActive
                        ? const Color(0xFF4CAF50)
                        : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Day chips
            Row(
              children: List.generate(7, (dow) {
                final active = schedule.daysOfWeek.contains(dow);
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 32,
                    height: 28,
                    decoration: BoxDecoration(
                      color: active ? color.withValues(alpha:0.15) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: active
                          ? Border.all(color: color, width: 1.5)
                          : Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text(
                        dayShort[dow],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active ? color : Colors.grey.shade400,
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
