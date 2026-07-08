import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onRegisterSuccess;
  const RegisterPage({super.key, required this.onRegisterSuccess});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final AuthService _auth = AuthService();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = '两次密码输入不一致');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final user = await _auth.register(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        nickname: _nicknameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (user != null && mounted) {
        Navigator.pop(context); // 注册成功，关闭注册页
        widget.onRegisterSuccess();
      } else if (mounted) {
        setState(() { _loading = false; _error = '注册失败，用户名可能已被占用'; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = _getErrorMessage(e); });
      }
    }
  }

  /// 将异常转换为用户可读的中文提示
  String _getErrorMessage(dynamic e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '网络连接超时，请检查网络后重试';
        case DioExceptionType.connectionError:
          return '网络不可用，请检查网络连接';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          final detail = e.response?.data?['detail'] ?? '';
          if (code == 400 && detail.toString().contains('用户名')) return '用户名已存在';
          if (code == 400) return detail.isNotEmpty ? '$detail' : '注册失败，请检查输入';
          if (code == 422) return '输入格式有误，请检查后重试';
          if (code != null && code >= 500) return '服务器繁忙，请稍后再试';
          return '注册失败（${code ?? '未知错误'}）';
        default:
          return '网络异常，请稍后再试';
      }
    }
    return '注册失败，请重试';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/app_icon.png',
                    width: 80, height: 80),
                const SizedBox(height: 20),
                const Text(
                  '注册账号',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                const Text('创建账户开始使用 电满满', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 40),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: InputDecoration(
                            labelText: '用户名',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().length < 3) ? '用户名至少3位' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nicknameCtrl,
                          decoration: InputDecoration(
                            labelText: '昵称（选填）',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          decoration: InputDecoration(
                            labelText: '手机号（选填，11位）',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (v.trim().length != 11) return '手机号为11位数字';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? '密码至少6位' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: '确认密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? '请再次输入密码' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _loading ? null : _register,
                            child: _loading
                                ? const SizedBox(width:24, height:24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('注册', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('已有账号？', style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => LoginPage(onLoginSuccess: widget.onRegisterSuccess)),
                        );
                      },
                      child: const Text('立即登录', style: TextStyle(color: Color(0xFF007AFF))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
