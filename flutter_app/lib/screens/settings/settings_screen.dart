import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fontScale = ref.watch(fontScaleProvider);

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
