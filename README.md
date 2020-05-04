# flutter_qr_scan

A lightweight QR-code scanning plugin for flutter.

⚠️ This package is still in alpha stage! ⚠️

## Integration

### Android specific

Open the project in `Android Studio`, by opening `example/android/build.gradle`.

Add the barcode ML model to the AndroidManifest.xml file of the app.
https://firebase.google.com/docs/ml-kit/android/read-barcodes

```xml
<application ...>
  ...
  <meta-data android:name="com.google.firebase.ml.vision.DEPENDENCIES" android:value="barcode" />
  <!-- To use multiple models: android:value="barcode,model2,model3" -->
</application>
```
