# Flutter's desired Proguard rules for release builds.
-dontwarn io.flutter.embedding.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclassmembers class * extends android.view.View {
    void set*(***);
    *** get*();
}
-keepclassmembers class * extends android.app.Activity {
   public void * (android.view.View);
}
-keepclassmembers class * extends android.app.Service {
   public void * (android.view.View);
}
-keepclassmembers class * extends android.content.ContentProvider {
   public void * (android.view.View);
}
-keepclassmembers class * extends android.content.BroadcastReceiver {
   public void * (android.view.View);
}
-keepclassmembers class * extends android.preference.Preference {
   public void * (android.view.View);
}
-keep class **.R$* {
    <fields>;
}
-keepclassmembers class fqcn.of.javascript.interface.for.webview {
   public *;
}
-keepclassmembers class * extends androidx.lifecycle.ViewModel {
    <init>();
}
