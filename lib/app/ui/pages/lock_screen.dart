import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({required this.onUnlock, super.key});

  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_lock_password') ?? '';
    if (_controller.text == saved) {
      widget.onUnlock();
    } else {
      setState(() => _error = '密码错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: scheme.primary),
              const SizedBox(height: 16),
              Text('AutoTalk Pro', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('应用已锁定，请输入密码', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '密码',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _unlock,
                  child: const Text('解锁'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 锁屏设置（在AI设置或侧边栏调用）
class LockSettings {
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('app_lock_password') ?? '').isNotEmpty;
  }

  static Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (password.isEmpty) {
      await prefs.remove('app_lock_password');
    } else {
      await prefs.setString('app_lock_password', password);
    }
  }

  static Future<void> removePassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_lock_password');
  }
}
