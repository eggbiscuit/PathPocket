import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'font_scale_provider.dart';
import 'theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ── 外观 ──────────────────────────────────────────────
          const _SectionHeader('外观'),
          _ThemeTile(current: themeMode),
          const Divider(height: 1),
          // ── 字体 ──────────────────────────────────────────────
          const _SectionHeader('字体'),
          _FontScaleTile(current: fontScale),
          const Divider(height: 1),
          // ── 关于 ──────────────────────────────────────────────
          const _SectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('PathPocket'),
            subtitle: const Text('病理问答助手 · 仅供学术参考'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Theme tile ──────────────────────────────────────────────────────────────

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.current});
  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.brightness_6_outlined, size: 22),
          const SizedBox(width: 16),
          const Expanded(child: Text('主题')),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto, size: 16),
                label: Text('跟随系统'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode, size: 16),
                label: Text('浅色'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode, size: 16),
                label: Text('深色'),
              ),
            ],
            selected: {current},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setMode(s.first),
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Font scale tile ─────────────────────────────────────────────────────────

class _FontScaleTile extends ConsumerWidget {
  const _FontScaleTile({required this.current});
  final double current;

  static final _labels = <double, String>{
    0.85: '小',
    1.0: '标准',
    1.15: '大',
    1.3: '超大',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.text_fields_outlined, size: 22),
          const SizedBox(width: 16),
          const Expanded(child: Text('字体大小')),
          SegmentedButton<double>(
            segments: fontScaleSteps
                .map((s) => ButtonSegment<double>(
                      value: s,
                      label: Text(_labels[s] ?? s.toString()),
                    ))
                .toList(),
            selected: {current},
            onSelectionChanged: (s) =>
                ref.read(fontScaleProvider.notifier).setScale(s.first),
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}
