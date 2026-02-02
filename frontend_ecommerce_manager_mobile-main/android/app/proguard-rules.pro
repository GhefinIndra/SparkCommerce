# ============================================================
# Flutter Core - Required
# ============================================================
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.** { *; }

# ============================================================
# Security Hardening - Obfuscation Rules
# ============================================================

# Obfuscate all class names aggressively
-repackageclasses ''
-allowaccessmodification

# Remove debugging information
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Optimize bytecode aggressively
-optimizationpasses 5
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Remove print statements (Dart prints become Android logs)
-assumenosideeffects class java.io.PrintStream {
    public void println(...);
    public void print(...);
}

# ============================================================
# String Protection
# ============================================================

# Encrypt string constants (R8 full mode)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Obfuscate dictionary - use random strings
-obfuscationdictionary proguard-dict.txt
-classobfuscationdictionary proguard-dict.txt
-packageobfuscationdictionary proguard-dict.txt

# ============================================================
# Native Library Protection
# ============================================================

# Don't warn about native methods
-dontwarn dalvik.**
-dontwarn com.android.org.conscrypt.**

# Keep native methods but obfuscate their containing classes
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================================
# Reflection Protection
# ============================================================

# Prevent reflection-based attacks on sensitive classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ============================================================
# Additional Security Measures
# ============================================================

# Remove unused code
-dontnote **
-dontwarn **

# Flatten package hierarchy
-flattenpackagehierarchy

# Merge interfaces where possible
-mergeinterfacesaggressively

