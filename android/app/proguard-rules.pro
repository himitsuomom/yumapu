# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / Ktor (uses reflection for JSON serialization)
-keep class io.ktor.** { *; }
-keepattributes *Annotation*, Signature, Exception
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class ** {
    @kotlinx.serialization.SerialName <fields>;
}

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# AdMob
-keep class com.google.android.gms.ads.** { *; }

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }

# Google Maps
-keep class com.google.maps.android.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keepclassmembers class ** implements kotlin.coroutines.CoroutineContext { *; }

# General
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
