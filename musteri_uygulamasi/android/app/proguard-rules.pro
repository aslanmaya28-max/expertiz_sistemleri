# Flutter ve eklentiler kendi consumer kurallarını sağlar. JNI/WebView köprülerini koru.
-keepattributes Signature,InnerClasses,EnclosingMethod,RuntimeVisibleAnnotations,AnnotationDefault
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
# Play Billing'in callback/Parcelable modelleri sürüm derlemesinde korunur.
-keep class com.android.billingclient.api.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }
# Güvenli depolamada Android Keystore algoritmaları reflection ile bulunabilir.
-keep class com.it_nomads.fluttersecurestorage.ciphers.** { *; }
