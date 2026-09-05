import 'package:flutter/material.dart';

import 'platform/window_init.dart';
import 'screens/home_screen.dart';
import 'services/config_service.dart';
import 'theme/app_typography.dart';
import 'themes/app_themes.dart';
import 'models/app_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.instance.init();
  final config = await ConfigService.instance.load();
  final launchTheme = getTheme(config.themeId ?? ThemeId.darkPurple);
  await initWindowIfDesktop(backgroundColor: Color(launchTheme.bg));
  runApp(const ImageGenApp());
}

class ImageGenApp extends StatelessWidget {
  const ImageGenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTypography.mergeInto(
      ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ImageGen',
      theme: theme,
      builder: (context, child) => AppTypography.wrapDefaultTextStyle(
        brightness: theme.brightness,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
