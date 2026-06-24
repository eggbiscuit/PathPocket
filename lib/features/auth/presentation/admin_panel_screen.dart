import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'admin_provider.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final state = ref.watch(adminPanelProvider);

    return Scaffold(
      backgroundColor: p.bgPage,
      appBar: AppBar(
        backgroundColor: p.bgPage,
        elevation: 0,
        title: Text('用户审批',
            style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: p.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: p.textSecondary),
            onPressed: () =>
                ref.read(adminPanelProvider.notifier).refresh(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (state.isLoading && state.users.isEmpty) {
          return Center(
              child:
                  CircularProgressIndicator(color: p.primary, strokeWidth: 2));
        }
        if (state.errorMessage != null && state.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: p.error),
                const SizedBox(height: 12),
                Text(state.errorMessage!,
                    style: AppTextStyles.caption(context),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      ref.read(adminPanelProvider.notifier).refresh(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        if (state.users.isEmpty) {
          return Center(
            child: Text('没有待审批的用户',
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: p.textTertiary)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.users.length,
          separatorBuilder: (_, __) => Divider(color: p.divider, height: 1),
          itemBuilder: (_, i) {
            final u = state.users[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: p.primaryContainer,
                    child: Text(
                      (u.displayName ?? u.email).substring(0, 1).toUpperCase(),
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600, color: p.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (u.displayName != null)
                          Text(u.displayName!,
                              style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: p.textPrimary)),
                        Text(u.email,
                            style: GoogleFonts.dmSans(
                                fontSize: 13, color: p.textSecondary)),
                        Text(
                          _statusLabel(u.status),
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: _statusColor(u.status, p)),
                        ),
                      ],
                    ),
                  ),
                  if (u.status == 'pending') ...[
                    _ActionButton(
                      label: '通过',
                      color: p.primary,
                      loading: state.processingId == u.id,
                      onTap: () => ref
                          .read(adminPanelProvider.notifier)
                          .approve(u.id),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: '拒绝',
                      color: p.error,
                      loading: state.processingId == u.id,
                      onTap: () => ref
                          .read(adminPanelProvider.notifier)
                          .reject(u.id),
                    ),
                  ] else
                    _StatusChip(status: u.status, p: p),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'approved' => '已通过',
      'rejected' => '已拒绝',
      _ => '待审批',
    };
  }

  Color _statusColor(String status, AppPalette p) {
    return switch (status) {
      'approved' => p.primary,
      'rejected' => p.error,
      _ => p.textTertiary,
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.loading,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          minimumSize: Size.zero,
          textStyle: GoogleFonts.dmSans(fontSize: 13),
        ),
        child: loading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            : Text(label),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.p});
  final String status;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('已通过', p.primary),
      'rejected' => ('已拒绝', p.error),
      _ => ('待审批', p.textTertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
