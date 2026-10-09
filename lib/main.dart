import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/navigation/app_navigator.dart';
import 'core/responsive/responsive_widgets.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/notifications/presentation/providers/push_notification_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final pushNotificationService = await FirebaseBootstrap.initialize();

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pushNotificationServiceProvider.overrideWithValue(
        pushNotificationService,
      ),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const AltrixApp()),
  );
}

class AltrixApp extends StatelessWidget {
  const AltrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Altrixs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => ResponsiveAppBuilder(child: child!),
      home: const SplashScreen(),
    );
  }
}
