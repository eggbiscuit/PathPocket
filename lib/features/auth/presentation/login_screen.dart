import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('验证码已发送（mock：固定为 123456）'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // error surfaced via state.errorMessage
    }
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
    } catch (_) {
      // surfaced via state.errorMessage / SnackBar below
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      final err = next.errorMessage;
      if (err != null && err != prev?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            backgroundColor: AppColors.error,
            content: Text(err),
            behavior: SnackBarBehavior.floating,
          ));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.medical_services,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PathPocket',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '病理问答助手',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.timestamp,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildModeTabs(),
                  const SizedBox(height: 20),
                  _buildPhoneField(),
                  const SizedBox(height: 12),
                  if (_mode == _LoginMode.sms)
                    _buildCodeField()
                  else
                    _buildPasswordField(),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: state.isLoading ? null : _submit,
                    child: state.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_mode == _LoginMode.sms ? '登录' : '登录'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '本产品由 AI 生成回答，仅供学术参考，不构成医疗诊断。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.timestamp,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    return SegmentedButton<_LoginMode>(
      segments: const [
        ButtonSegment(value: _LoginMode.sms, label: Text('短信验证码')),
        ButtonSegment(value: _LoginMode.password, label: Text('密码登录')),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      maxLength: 11,
      decoration: const InputDecoration(
        labelText: '手机号',
        counterText: '',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildCodeField() {
    final canSend = _smsCountdown == 0 && _phone.text.trim().length == 11;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '验证码',
              counterText: '',
              prefixIcon: Icon(Icons.sms),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: canSend ? _sendCode : null,
            child: Text(
              _smsCountdown == 0 ? '获取验证码' : '${_smsCountdown}s',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _password,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: '密码',
        prefixIcon: Icon(Icons.lock),
        border: OutlineInputBorder(),
      ),
    );
  }
}
