# SECURITY (S9): R8/ProGuard rules for the release build.
# Flutter + plugin entry points must be kept; the rest is shrunk and renamed.

# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# --- Third-party SDKs that resolve classes reflectively ---

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ZEGO live streaming engine (loaded via JNI / reflection)
-keep class im.zego.** { *; }
-dontwarn im.zego.**

# DeepAR AR filters (native bridge + reflection)
-keep class ai.deepar.** { *; }
-dontwarn ai.deepar.**

# RevenueCat purchases (reflection over billing client)
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Supabase / Ktor / kotlinx-serialization (used by supabase_flutter)
-keepattributes *Annotation*, InnerClasses, Signature, EnclosingMethod
-keepclassmembers class kotlinx.serialization.** { *; }
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**
-dontwarn kotlinx.serialization.**

# Gson / model classes deserialized by name
-keepattributes Signature
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}
