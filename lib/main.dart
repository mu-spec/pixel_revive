import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_revive/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PixelReviveApp());
}