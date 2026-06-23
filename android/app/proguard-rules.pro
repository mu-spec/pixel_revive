# Flutter Default Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Image picker / provider
-keep class androidx.lifecycle.DefaultLifecycleObserver
-keep class io.flutter.plugins.imagepicker.** { *; }

# ML Kit face detection
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.**

# Ignore Play Core Split install missing classes (FIX FOR CODEMAGIC R8 ERROR)
-dontwarn com.google.android.play.core.**