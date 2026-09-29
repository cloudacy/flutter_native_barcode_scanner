# Prevent R8 from removing required no-arg constructors since AGP 9.
# Example:
#   Could not instantiate com.google.mlkit.common.internal.CommonComponentRegistrar
#     at com.google.mlkit.common.internal.MlKitInitProvider.onCreate(...)
#   Caused by: java.lang.NoSuchMethodException: com.google.mlkit.common.internal.CommonComponentRegistrar.<init> []
# See `strictFullModeForKeepRules` at https://developer.android.com/build/releases/agp-9-0-0-release-notes for details why.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
