import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/router/route_names.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/chat/chat_socket.dart';
import 'features/shared/chat/chat_unread.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: '.env');

  // When a session dies and token refresh fails, tear down the chat socket
  // (it carries the user's identity) and route back to login.
  DioClient.onSessionExpired = () {
    ChatUnread.instance.stop();
    ChatSocket.instance.dispose();
    appRouter.go(RouteNames.login);
  };

  // Force portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: YatraGoApp()));
}

class YatraGoApp extends StatelessWidget {
  const YatraGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'YatraGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
