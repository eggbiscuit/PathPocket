import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'auth_provider.dart';

/// Shown after registration (waiting for email verification) and after login
/// when the account is pending approval or email is unverified.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);
    final p = context.palette;

    final isUnverified = state.blocker == AuthBlocker.emailNotVerified;
    final isRejected = state.blocker == AuthBlocker.rejected;
    final isRegisterSuccess = state.registerSuccess;

    final (IconData icon, String title, String body) = isRejected
        ? (
            Icons.cancel_outlined,
            '审批未通过',
            '您的申请未通过，请联系管理员了解详情。',
          )
        : isUnverified
            ? (
                Icons.mark_email_unread_outlined,
                '请验证邮箱',
                '我们已向您的邮箱发送了验证链接，请点击链接完成验证后再尝试登录。',
              )
            : (
                Icons.hourglass_top_outlined,
                isRegisterSuccess ? '申请已提交' : '等待管理员审批',
                isRegisterSuccess
                    ? '已向您的邮箱发送验证链接，验证后请等待管理员审批，审批通过后即可登录。'
                    : '您的账号正在等待管理员审批，审批通过后即可登录。',
              );

    return Scaffold(
      backgroundColor: p.bgPage,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: isRejected ? p.error : p.primary),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: GoogleFonts.dmSerifDisplay(
                        fontSize: 24, color: p.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: p.textSecondary, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (!isRejected) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: state.isLoading
                            ? null
                            : () async {
                                // Re-attempt login with stored state — the router
                                // redirect will forward to '/' if now approved.
                                context.go('/login');
                              },
                        child: Text('重新检查状态',
                            style: GoogleFonts.dmSans(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                    child: Text('返回登录',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: p.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
