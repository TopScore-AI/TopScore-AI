# ML Kit ProGuard Rules
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# General ProGuard Rules for Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn io.flutter.embedding.**

# Play Core is referenced by Flutter's deferred components but not included
# when we don't use them. Silence R8 warnings so shrinking can complete.
-dontwarn com.google.android.play.core.**

# Keep annotations that serialization libraries rely on.
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
