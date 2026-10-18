# Plugins are registered by class name at engine start; if R8 strips or
# renames them the app can die before drawing its first frame.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Google Sign-In / Credential Manager (google_sign_in_android).
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-dontwarn com.google.android.gms.**

# flutter_secure_storage (Android keystore access).
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# shared_preferences (Jetpack DataStore backend).
-keep class androidx.datastore.** { *; }

# flutter_local_notifications: stores scheduled notifications with Gson,
# which needs the generic type signatures R8 would otherwise drop.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
