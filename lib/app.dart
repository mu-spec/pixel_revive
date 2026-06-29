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
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: AppColors.primary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            secondary: AppColors.cyan,
            surface: AppColors.surface,
          ),
          textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'Roboto',
                bodyColor: AppColors.text,
                displayColor: AppColors.text,
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: AppColors.text),
            titleTextStyle: TextStyle(
              color: AppColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.card,
            elevation: 0,
            shadowColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
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