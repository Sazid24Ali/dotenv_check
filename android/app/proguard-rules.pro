# ML Kit Vision - Keep text recognizer classes
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Keep all ML Kit classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Firebase & GMS
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Flutter plugins (for method channel implementations)
-keep class io.flutter.plugins.** { *; }

# Flutter native methods
-keepclassmembers class * {
    native <methods>;
}
