import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/asset.dart';
import 'package:household/screens/assets/assets_view_model.dart';

const _purple = Color(0xFF667EEA);

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(assetsViewModelProvider);

    if (vm.noHousehold) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏠', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(l10n.commonNoHousehold,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(l10n.commonNoHouseholdMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF888888))),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            // ── Summary bar ───────────────────────────────────────────────
            _SummaryBar(vm: vm),
            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _buildBody(vm),
            ),
          ],
        ),
        // ── FAB ───────────────────────────────────────────────────────────
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              vm.openAddModal();
              _showAssetSheet(context);
            },
            backgroundColor: _purple,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(AssetsViewModel vm) {
    if (vm.state == AssetsLoadState.loading) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    if (vm.state == AssetsLoadState.error) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.assetsLoadFailed,
                style: const TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: vm.load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (vm.assetGroups.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💰', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(l10n.assetsNoAssets,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(l10n.assetsNoAssetsSub,
                style: const TextStyle(color: Color(0xFF888888))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: vm.assetGroups.length,
      itemBuilder: (context, i) {
        final group = vm.assetGroups[i];
        return _AssetGroupCard(
          group: group,
          onEdit: (asset) {
            vm.openEditModal(asset);
            _showAssetSheet(context);
          },
          onDelete: (asset) => _confirmDelete(context, vm, asset),
          onLiquidityChanged: (asset, liq) =>
              vm.patchAsset(asset, {'liquidity': liq}),
        );
      },
    );
  }

  void _showAssetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AssetFormSheet(),
    );
  }

  void _confirmDelete(
      BuildContext context, AssetsViewModel vm, Asset asset) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.commonDeleteAsset),
        content: Text('Delete "${asset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteAsset(asset);
            },
            child: Text(l10n.commonDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Summary bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final AssetsViewModel vm;
  const _SummaryBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryCard(label: AppLocalizations.of(context)!.assetsTotal, value: vm.totalValue, dot: null, accent: _purple)),
          const SizedBox(width: 6),
          Expanded(child: _SummaryCard(label: AppLocalizations.of(context)!.assetsLiquid, value: vm.liquidValue, dot: '🟢', accent: const Color(0xFF4CAF50))),
          const SizedBox(width: 6),
          Expanded(child: _SummaryCard(label: AppLocalizations.of(context)!.assetsSemi, value: vm.semiLiquidValue, dot: '🟡', accent: const Color(0xFFFFC107))),
          const SizedBox(width: 6),
          Expanded(child: _SummaryCard(label: AppLocalizations.of(context)!.assetsIlliquid, value: vm.illiquidValue, dot: '🔴', accent: const Color(0xFFF44336))),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final String? dot;
  final Color accent;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.dot,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = '₪${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (dot != null) ...[
                Text(dot!, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Asset group card ─────────────────────────────────────────────────────────

class _AssetGroupCard extends StatelessWidget {
  final AssetGroup group;
  final void Function(Asset) onEdit;
  final void Function(Asset) onDelete;
  final void Function(Asset, String) onLiquidityChanged;

  const _AssetGroupCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onLiquidityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.assets.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Asset rows
          ...group.assets.asMap().entries.map((entry) {
            final idx = entry.key;
            final asset = entry.value;
            return _AssetRow(
              asset: asset,
              isEven: idx.isEven,
              onEdit: () => onEdit(asset),
              onDelete: () => onDelete(asset),
              onLiquidityChanged: (liq) => onLiquidityChanged(asset, liq),
            );
          }),
          // Group total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: group.mismatch
                  ? const Color(0xFFFFF3E0)
                  : const Color(0xFFF5F5F5),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.assetsGroupTotal,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatCurrency(group.frontendTotal),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
                if (group.mismatch) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Frontend total does not match backend total',
                    child: Text('⚠️', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCurrency(double value) {
    return '₪${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  }
}

// ─── Individual asset row ─────────────────────────────────────────────────────

class _AssetRow extends StatelessWidget {
  final Asset asset;
  final bool isEven;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String) onLiquidityChanged;

  const _AssetRow({
    required this.asset,
    required this.isEven,
    required this.onEdit,
    required this.onDelete,
    required this.onLiquidityChanged,
  });

  static const _liquidityColors = {
    'high': Color(0xFF4CAF50),
    'medium': Color(0xFFFFC107),
    'low': Color(0xFFF44336),
  };

  static const _liquidityDots = {
    'high': '🟢',
    'medium': '🟡',
    'low': '🔴',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final liquidityLabels = {
      'high': l10n.assetsLiquidityHigh,
      'medium': l10n.assetsLiquidityMedium,
      'low': l10n.assetsLiquidityLow,
    };
    final liqColor = _liquidityColors[asset.liquidity] ?? const Color(0xFF888888);
    final liqDot = _liquidityDots[asset.liquidity] ?? '';
    final liqLabel = liquidityLabels[asset.liquidity] ?? asset.liquidity;
    final dateDisplay = asset.date != null && asset.date!.isNotEmpty
        ? asset.date!.substring(0, 10)
        : '—';
    final valueDisplay =
        '₪${asset.value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

    return InkWell(
      onTap: onEdit,
      child: Container(
        color: isEven ? Colors.white : const Color(0xFFFAFAFA),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Date
            SizedBox(
              width: 80,
              child: Text(
                dateDisplay,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ),
            // Value
            SizedBox(
              width: 90,
              child: Text(
                valueDisplay,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222)),
              ),
            ),
            // Liquidity badge
            GestureDetector(
              onTap: () => _showLiquidityPicker(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: liqColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: liqColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(liqDot, style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Text(
                      liqLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: liqColor),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Description
            if (asset.description?.isNotEmpty == true)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    asset.description!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Delete
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFCCCCCC)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLiquidityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.assetsSetLiquidity,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              for (final entry in [
                ('high', '🟢', l10n.assetsLiquidityHigh),
                ('medium', '🟡', l10n.assetsLiquidityMedium),
                ('low', '🔴', l10n.assetsLiquidityLow),
              ])
              ListTile(
                leading: Text(entry.$2,
                    style: const TextStyle(fontSize: 20)),
                title: Text(entry.$3),
                selected: asset.liquidity == entry.$1,
                selectedColor: _purple,
                onTap: () {
                  Navigator.pop(ctx);
                  onLiquidityChanged(entry.$1);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ─── Add / Edit bottom sheet ──────────────────────────────────────────────────

class _AssetFormSheet extends ConsumerStatefulWidget {
  const _AssetFormSheet();

  @override
  ConsumerState<_AssetFormSheet> createState() => _AssetFormSheetState();
}

class _AssetFormSheetState extends ConsumerState<_AssetFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _valueCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _exitSeriesIntervalCtrl;
  late TextEditingController _repetitiveAmountCtrl;
  late TextEditingController _repetitiveIntervalCtrl;

  @override
  void initState() {
    super.initState();
    final vm = ref.read(assetsViewModelProvider);
    _nameCtrl = TextEditingController(text: vm.formName);
    _valueCtrl = TextEditingController(
        text: vm.formValue == 0 ? '' : vm.formValue.toString());
    _descCtrl = TextEditingController(text: vm.formDescription);
    _dateCtrl = TextEditingController(text: vm.formDate);
    _exitSeriesIntervalCtrl = TextEditingController(
        text: vm.formExitSeriesInterval?.toString() ?? '');
    _repetitiveAmountCtrl = TextEditingController(
        text: vm.formRepetitiveAmount?.toString() ?? '');
    _repetitiveIntervalCtrl = TextEditingController(
        text: vm.formRepetitiveInterval?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _exitSeriesIntervalCtrl.dispose();
    _repetitiveAmountCtrl.dispose();
    _repetitiveIntervalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(assetsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Text(
                  vm.isEditMode ? l10n.assetsEdit : l10n.assetsNew,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    vm.closeModal();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            // Error
            if (vm.modalError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(vm.modalError!,
                    style: const TextStyle(
                        color: Color(0xFFD32F2F), fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),
            // Name
            _buildLabel(l10n.assetsName),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              onChanged: vm.setFormName,
              decoration: _inputDeco('e.g. Savings Account'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            // Value
            _buildLabel(l10n.assetsValue),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFFE0E0E0), width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFFAFAFA),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('₪',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444))),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600),
                      onChanged: (v) =>
                          vm.setFormValue(double.tryParse(v) ?? 0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Liquidity
            _buildLabel(l10n.assetsLiquidity),
            const SizedBox(height: 8),
            _buildLiquiditySegment(vm, l10n),
            const SizedBox(height: 16),
            // Date
            _buildLabel(l10n.assetsDate),
            const SizedBox(height: 8),
            _buildDatePicker(
              context: context,
              displayText: vm.formDate.isNotEmpty ? vm.formDate : l10n.assetsSelectDate,
              onPick: (picked) {
                final formatted = _formatDate(picked);
                vm.setFormDate(formatted);
                _dateCtrl.text = formatted;
              },
            ),
            const SizedBox(height: 16),
            // Description
            _buildLabel(l10n.assetsDescription, optional: true),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              onChanged: vm.setFormDescription,
              decoration: _inputDeco('e.g. IBI savings'),
              maxLength: 200,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
            ),
            const SizedBox(height: 20),

            // ── Exit section ──────────────────────────────────────────────
            _buildSectionDivider(l10n.assetsExitDate),
            const SizedBox(height: 12),
            _buildExitTypeToggle(vm, l10n),
            if (vm.formExitType == 'single') ...[
              const SizedBox(height: 12),
              _buildLabel(l10n.assetsExitDate),
              const SizedBox(height: 8),
              _buildDatePicker(
                context: context,
                displayText: vm.formExitDate != null
                    ? _formatDate(vm.formExitDate!)
                    : l10n.assetsSelectExitDate,
                onPick: (picked) => vm.setFormExitDate(picked),
              ),
            ],
            if (vm.formExitType == 'series') ...[
              const SizedBox(height: 12),
              _buildLabel(l10n.assetsExitSeriesStart),
              const SizedBox(height: 8),
              _buildDatePicker(
                context: context,
                displayText: vm.formExitSeriesStart != null
                    ? _formatDate(vm.formExitSeriesStart!)
                    : l10n.assetsSelectStartDate,
                onPick: (picked) => vm.setFormExitSeriesStart(picked),
              ),
              const SizedBox(height: 12),
              _buildLabel(l10n.assetsRepeatEvery),
              const SizedBox(height: 8),
              _buildIntervalRow(
                context: context,
                intervalCtrl: _exitSeriesIntervalCtrl,
                onIntervalChanged: (v) =>
                    vm.setFormExitSeriesInterval(int.tryParse(v)),
                selectedUnit: vm.formExitSeriesUnit,
                onUnitChanged: vm.setFormExitSeriesUnit,
              ),
            ],
            const SizedBox(height: 20),

            // ── Repetitive income section ─────────────────────────────────
            _buildSectionDivider(l10n.assetsRecurringIncome),
            const SizedBox(height: 12),
            _buildRepetitiveToggle(vm, l10n),
            if (vm.formIsRepetitive) ...[
              const SizedBox(height: 12),
              _buildLabel(l10n.assetsAmountPerInterval),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFE0E0E0), width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFAFAFA),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('₪',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF444444))),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _repetitiveAmountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 16),
                        onChanged: (v) =>
                            vm.setFormRepetitiveAmount(double.tryParse(v)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildLabel(l10n.assetsRepeatEvery),
              const SizedBox(height: 8),
              _buildIntervalRow(
                context: context,
                intervalCtrl: _repetitiveIntervalCtrl,
                onIntervalChanged: (v) =>
                    vm.setFormRepetitiveInterval(int.tryParse(v)),
                selectedUnit: vm.formRepetitiveUnit,
                onUnitChanged: vm.setFormRepetitiveUnit,
              ),
            ],
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.modalSaving
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        await vm.saveAsset();
                        if (!vm.modalOpen && vm.modalError == null) {
                          nav.pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: vm.modalSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        vm.isEditMode ? l10n.assetsSave : l10n.assetsAdd,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: date picker tile ───────────────────────────────────────────────

  Widget _buildDatePicker({
    required BuildContext context,
    required String displayText,
    required void Function(DateTime) onPick,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border:
              Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFFAFAFA),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 16, color: Color(0xFF888888)),
            const SizedBox(width: 8),
            Text(
              displayText,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF333333)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: interval row (number + unit dropdown) ─────────────────────────

  Widget _buildIntervalRow({
    required BuildContext context,
    required TextEditingController intervalCtrl,
    required void Function(String) onIntervalChanged,
    required String selectedUnit,
    required void Function(String) onUnitChanged,
  }) {
    const units = ['days', 'weeks', 'months', 'years'];
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: intervalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco('e.g. 1'),
            onChanged: onIntervalChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border:
                  Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFAFAFA),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedUnit,
                isExpanded: true,
                items: units
                    .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u[0].toUpperCase() + u.substring(1),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onUnitChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper: exit type 3-button toggle ────────────────────────────────────

  Widget _buildExitTypeToggle(AssetsViewModel vm, AppLocalizations l10n) {
    final options = [
      ('none', l10n.assetsExitNone),
      ('single', l10n.assetsExitSingle),
      ('series', l10n.assetsExitSeries),
    ];
    return Row(
      children: options.map((opt) {
        final active = vm.formExitType == opt.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => vm.setFormExitType(opt.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? _purple : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : const Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Helper: repetitive income toggle ─────────────────────────────────────

  Widget _buildRepetitiveToggle(AssetsViewModel vm, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.assetsRecurringIncome,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333)),
          ),
        ),
        Switch(
          value: vm.formIsRepetitive,
          onChanged: vm.setFormIsRepetitive,
          activeThumbColor: _purple,
        ),
      ],
    );
  }

  // ── Helper: section divider ────────────────────────────────────────────────

  Widget _buildSectionDivider(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _purple,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
      ],
    );
  }

  Widget _buildLiquiditySegment(AssetsViewModel vm, AppLocalizations l10n) {
    final options = [
      ('high', '🟢', l10n.assetsLiquidityHigh),
      ('medium', '🟡', l10n.assetsLiquidityMedium),
      ('low', '🔴', l10n.assetsLiquidityLow),
    ];
    return Row(
      children: options.map((opt) {
        final active = vm.formLiquidity == opt.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => vm.setFormLiquidity(opt.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? _purple : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(opt.$2, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    opt.$3,
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? Colors.white : const Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabel(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444444))),
        if (optional)
          Text(' ${AppLocalizations.of(context)!.commonOptional}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFFE0E0E0), width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFFE0E0E0), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: _purple, width: 1.5)),
      );

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
