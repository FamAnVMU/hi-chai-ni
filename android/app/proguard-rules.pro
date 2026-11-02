# ProGuard & R8 Optimization Rules for HI Chinese

# Flutter core and plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLite & Native Database Drivers
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Security & SharedPreferences
-keep class androidx.security.crypto.** { *; }

# Suppress known harmless warnings
-dontwarn io.flutter.embedding.**
