# ProGuard rules for Smart Charge App

# Keep all classes in the amap package
-keep class com.amap.api.** { *; }
-keep class com.autonavi.** { *; }

# Keep all native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep generic signatures for reflection
-keepattributes Signature
-keepattributes *Annotation*

# Keep line number information for stack traces
-keepattributes SourceFile,LineNumberTable

# Keep Android activity, service, etc.
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.Application
-keep public class * extends android.view.View

# For Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# For Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Ignore warnings about Amap SDK
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**

# Ignore SELinux warnings about /proc/fas/render
-dontwarn android.system.**

# Keep R classes
-keep class **.R$* { *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}