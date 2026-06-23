import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/splash_screen.dart';

class PixelReviveApp extends StatelessWidget {
  const PixelReviveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.primary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            secondary: AppColors.success,
            surface: AppColors.surface,
            background: AppColors.primary,
            onBackground: AppColors.text,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: AppColors.text),
            titleTextStyle: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}