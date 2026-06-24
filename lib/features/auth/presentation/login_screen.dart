import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final p = context.palette;

    ref.listen<AuthState>(authProvider, (prev, next) {
      final err = next.errorMessage;
      if (err != null && err != prev?.errorMessage) {
        // Non-blocking states show a dedicated screen via router redirect;
        // for generic errors fall back to a snack bar.
        if (next.blocker == AuthBlocker.none) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              backgroundColor: p.error,
              content: Text(err),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ));
        }
      }
      // Navigate to pending screen when the blocker is set.
      if (next.blocker != AuthBlocker.none &&
          next.blocker != (prev?.blocker ?? AuthBlocker.none)) {
        context.go('/pending');
      }
    });

    return Scaffold(
      backgroundColor: p.bgPage,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: p.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Icon(Icons.biotech_outlined,
                            size: 32, color: p.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'PathPocket',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 28,
                        color: p.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'HKUST SmartX Lab · 病理学 AI 助手',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: p.textSecondary),
                    ),
                    const SizedBox(height: 36),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.dmSans(color: p.textPrimary),
                      decoration: InputDecoration(
                        labelText: '邮箱',
                        labelStyle:
                            GoogleFonts.dmSans(color: p.textTertiary),
                        prefixIcon: Icon(Icons.email_outlined,
                            size: 18, color: p.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style: GoogleFonts.dmSans(color: p.textPrimary),
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '密码',
                        labelStyle:
                            GoogleFonts.dmSans(color: p.textTertiary),
                        prefixIcon: Icon(Icons.lock_outline,
                            size: 18, color: p.textTertiary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: p.textTertiary,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: state.isLoading ? null : _submit,
                        child: state.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text('登录',
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('还没有账号？',
                            style: GoogleFonts.dmSans(
                                fontSize: 13, color: p.textSecondary)),
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                          ),
                          onPressed: () => context.go('/register'),
                          child: Text('申请注册',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: p.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '本产品由 AI 生成回答，仅供学术参考，不构成医疗诊断。',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, height: 1.5, color: p.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
