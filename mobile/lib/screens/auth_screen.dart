import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/format.dart';
import '../widgets/animated_press.dart';

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
          padding: const EdgeInsets.all(AppSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.authWidth),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: AppLayout.emptyIconSize,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Sổ Chi Tiêu',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  const Text(
                    'Hiểu dòng tiền. Chủ động mỗi ngày.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.section),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: Text(
                      register
                          ? 'Tạo tài khoản cá nhân'
                          : 'Chào mừng bạn trở lại',
                      key: ValueKey(register),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  AnimatedSize(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: register
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                              const SizedBox(height: AppSpace.lg),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
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
                  const SizedBox(height: AppSpace.lg),
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
                        tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
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
                  const SizedBox(height: AppSpace.xl),
                  AnimatedPress(
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Text(
                          busy
                              ? 'Đang xử lý…'
                              : register
                              ? 'Đăng ký'
                              : 'Đăng nhập',
                        ),
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
