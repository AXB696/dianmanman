import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_client.dart';
import 'home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SmartChargeV2App());
}

class SmartChargeV2App extends StatelessWidget {
  const SmartChargeV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Charge V2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        fontFamily: 'Helvetica',
        primaryColor: const Color(0xFF007AFF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF34C759),
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthBootWrapper(),
    );
  }
}

class AuthBootWrapper extends StatefulWidget {
  const AuthBootWrapper({super.key});

  @override
  State<AuthBootWrapper> createState() => _AuthBootWrapperState();
}

class _AuthBootWrapperState extends State<AuthBootWrapper> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final client = ApiClient();
    // 初始化 server URL
    final savedUrl = await client.getServerUrl();
    if (savedUrl != null) {
      await client.init(savedUrl);
    } else {
      await client.saveServerUrl('https://3aa33e7d.cpolar.io');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ev_station, size: 64, color: Color(0xFF007AFF)),
              SizedBox(height: 20),
              Text('Smart Charge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Color(0xFF007AFF)),
            ],
          ),
        ),
      );
    }
    // 直接进入主页，登录功能在个人中心按需使用
    return SleekHomeWrapper(onLogout: () {});
  }
}
