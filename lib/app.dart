import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/splash_screen.dart';

class PixelReviveApp extends StatelessWidget {
  const PixelReviveApp({super.key});

  /// Languages that should display in right-to-left layout.
  static const Set<String> _rtlLanguages = {'ur', 'ar'};

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        // Wrap the entire app in a Directionality that flips to RTL for
        // Urdu/Arabic. Consumer rebuilds the whole tree whenever the user
        // changes the language, so layout direction updates live.
        builder: (context, child) {
          final langCode = context.watch<AppProvider>().languageCode;
          final isRtl = _rtlLanguages.contains(langCode);
          return Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.primary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            secondary: AppColors.success,
            surface: AppColors.surface,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: AppColors.text),
            titleTextStyle: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.card,
            elevation: 8,
            shadowColor: Colors.black54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: Colors.white.withOpacity(0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}