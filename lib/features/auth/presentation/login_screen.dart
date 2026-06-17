import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'auth_provider.dart';

enum _LoginMode { sms, password }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  _LoginMode _mode = _LoginMode.sms;
  int _smsCountdown = 0;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    try {
      await ref.read(authProvider.notifier).sendSmsCode(_phone.text.trim());
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('验证码已发送（mock：固定为 123456）'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ));
      }
    } catch (_) {}
  }

  void _startCountdown() {
    setState(() => _smsCountdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _smsCountdown -= 1);
      return _smsCountdown > 0;
    });
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    try {
      if (_mode == _LoginMode.sms) {
        await ref
            .read(authProvider.notifier)
            .verifySmsCode(phone, _code.text.trim());
      } else {
        await ref
            .read(authProvider.notifier)
            .loginWithPassword(phone, _password.text);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final p = context.palette;

    ref.listen<AuthState>(authProvider, (prev, next) {
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
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
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        Icons.biotech_outlined,
                        size: 32,
                        color: p.primary,
                      ),
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
                      fontSize: 13,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SegmentedButton<_LoginMode>(
                    segments: [
                      ButtonSegment(
                        value: _LoginMode.sms,
                        label: const Text('短信验证码'),
                      ),
                      ButtonSegment(
                        value: _LoginMode.password,
                        label: const Text('密码登录'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) =>
                        setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    style: GoogleFonts.dmSans(
                      color: p.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: '手机号',
                      labelStyle: GoogleFonts.dmSans(color: p.textTertiary),
                      counterText: '',
                      prefixIcon: Icon(Icons.phone_outlined,
                          size: 18, color: p.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_mode == _LoginMode.sms)
                    _buildCodeField(p)
                  else
                    _buildPasswordField(p),
                  const SizedBox(height: 20),
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
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '本产品由 AI 生成回答，仅供学术参考，不构成医疗诊断。',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      height: 1.5,
                      color: p.textTertiary,
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

  Widget _buildCodeField(AppPalette p) {
    final canSend = _smsCountdown == 0 && _phone.text.trim().length == 11;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: GoogleFonts.dmSans(
              color: p.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: '验证码',
              labelStyle: GoogleFonts.dmSans(color: p.textTertiary),
              counterText: '',
              prefixIcon: Icon(Icons.sms_outlined,
                  size: 18, color: p.textTertiary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: canSend ? _sendCode : null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: canSend ? p.primary : p.divider,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              textStyle: GoogleFonts.dmSans(fontSize: 13),
            ),
            child: Text(
                _smsCountdown == 0 ? '获取验证码' : '${_smsCountdown}s'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(AppPalette p) {
    return TextField(
      controller: _password,
      obscureText: true,
      style: GoogleFonts.dmSans(
        color: p.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: '密码',
        labelStyle: GoogleFonts.dmSans(color: p.textTertiary),
        prefixIcon: Icon(Icons.lock_outline,
            size: 18, color: p.textTertiary),
      ),
    );
  }
}
