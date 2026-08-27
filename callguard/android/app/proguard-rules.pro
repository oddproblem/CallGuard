-keep class com.cloudwebrtc.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# TFLite — keep native bindings for release builds
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
