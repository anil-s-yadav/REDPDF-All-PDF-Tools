import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:redpdf_tools/firebase_options.dart';
import 'package:redpdf_tools/providers/pdf_provider.dart';
import 'package:redpdf_tools/providers/theme_provider.dart';
// import '../providers/pdf_provider.dart';
import 'package:redpdf_tools/providers/settings_provider.dart';
import 'screens/navigation.dart';
import 'screens/tools_screen.dart';
import 'package:redpdf_tools/theme/app_theme.dart';
import 'package:redpdf_tools/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.initialize();
  await ToolsScreen.initPreferences();
  runApp(
    MultiProvider(
      providers: [
        // Provider<AuthRepository>.value(value: authRepository),
        // Provider<UserRepository>.value(value: userRepository),
        // ChangeNotifierProvider(
        //   create: (_) => AuthProvider(authRepository, userRepository),
        // ),
        ChangeNotifierProvider(create: (_) => PdfProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer
    //2
    <
      ThemeProvider
      //, AuthProvider
    >(
      builder:
          (
            context,
            themeProvider,
            //authProvider,
            child,
          ) {
            return MaterialApp(
              title: 'RedPdf',
              debugShowCheckedModeBanner: kDebugMode,
              themeMode: themeProvider.themeMode,
              theme: AppTheme.lightMode,
              darkTheme: AppTheme.darkMode,
              home: const Navigation(),
            );
          },
    );
  }
}
