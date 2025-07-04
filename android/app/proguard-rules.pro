# Keep all ML Kit vision text classes (for dynamic loading)
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Optional: keep all ML Kit classes if needed
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
