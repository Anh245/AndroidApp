import 'package:flutter/material.dart';
import '../core/session.dart';
import '../core/format.dart';

class AuthScreen extends StatefulWidget {
  final Session session;
  const AuthScreen({super.key, required this.session});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool register = false, busy = false, hidden = true;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.session.signIn(
        email.text,
        password.text,
        name: register ? name.text : null,
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 70,
                    color: Color(0xFF0F766E),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sổ Chi Tiêu',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hiểu dòng tiền. Chủ động mỗi ngày.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    register
                        ? 'Tạo tài khoản cá nhân'
                        : 'Chào mừng bạn trở lại',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  if (register) ...[
                    TextFormField(
                      controller: name,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Họ tên',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? 'Nhập ít nhất 2 ký tự'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    maxLength: 254,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      counterText: '',
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Nhập email hợp lệ',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    obscureText: hidden,
                    maxLength: 128,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      helperText: 'Từ 8 đến 128 ký tự',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => hidden = !hidden),
                        icon: Icon(
                          hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => (v?.length ?? 0) < 8
                        ? 'Mật khẩu cần ít nhất 8 ký tự'
                        : null,
                    onFieldSubmitted: (_) {
                      if (!busy) submit();
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        busy
                            ? 'Đang xử lý…'
                            : register
                            ? 'Đăng ký'
                            : 'Đăng nhập',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            register = !register;
                            form.currentState?.reset();
                          }),
                    child: Text(
                      register
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
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
