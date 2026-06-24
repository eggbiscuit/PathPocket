import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _obscure = true;
  String? _emailError;

  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  bool _validateEmail(String value) {
    if (!_emailRegex.hasMatch(value)) {
      setState(() => _emailError = '请输入有效的邮箱地址');
      return false;
    }
    setState(() => _emailError = null);
    return true;
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!_validateEmail(email)) return;
    await ref.read(authProvider.notifier).register(
          email,
          _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final p = context.palette;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.registerSuccess && !(prev?.registerSuccess ?? false)) {
        ref.read(authProvider.notifier).clearRegisterSuccess();
        context.go('/pending');
      }
      final err = next.errorMessage;
      if (err != null && err != prev?.errorMessage) {
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
    });

    return Scaffold(
      backgroundColor: p.bgPage,
      appBar: AppBar(
        backgroundColor: p.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.textSecondary),
          onPressed: () => context.go('/login'),
        ),
        title: Text('申请注册',
            style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: p.textPrimary)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '注册后需由管理员审批才能登录使用。',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: p.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (_emailError != null) _validateEmail(_email.text);
                      },
                      style: GoogleFonts.dmSans(color: p.textPrimary),
                      decoration: InputDecoration(
                        labelText: '邮箱 *',
                        labelStyle:
                            GoogleFonts.dmSans(color: p.textTertiary),
                        errorText: _emailError,
                        prefixIcon: Icon(Icons.email_outlined,
                            size: 18, color: p.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style: GoogleFonts.dmSans(color: p.textPrimary),
                      decoration: InputDecoration(
                        labelText: '密码（至少 6 位）*',
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      style: GoogleFonts.dmSans(color: p.textPrimary),
                      decoration: InputDecoration(
                        labelText: '姓名（可选）',
                        labelStyle:
                            GoogleFonts.dmSans(color: p.textTertiary),
                        prefixIcon: Icon(Icons.person_outline,
                            size: 18, color: p.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 28),
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
                            : Text('提交申请',
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                      ),
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
