import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_client.dart';
import 'services/data_repository.dart';
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
      title: '电满满 V2',
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
  int _refreshKey = 0; // 登录/登出后强制重建主页，刷新数据源

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. 初始化 API 客户端（服务器地址）
    final client = ApiClient();
    final savedUrl = await client.getServerUrl();
    if (savedUrl != null) {
      await client.init(savedUrl);
    } else {
      await client.saveServerUrl('http://39.106.96.59:80');
    }

    // 2. 初始化数据仓库（检测登录状态）
    await DataRepository().init();

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
              Text('电满满',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Color(0xFF007AFF)),
            ],
          ),
        ),
      );
    }

    // 无论游客还是登录用户，都进入主页
    // ValueKey 确保登录/登出后主页完全重建，重新从正确的数据源加载
    return SleekHomeWrapper(
      key: ValueKey(_refreshKey),
      onLogout: () {
        // 登出或登录状态变化时，强制重建主页
        setState(() => _refreshKey++);
      },
    );
  }
}
