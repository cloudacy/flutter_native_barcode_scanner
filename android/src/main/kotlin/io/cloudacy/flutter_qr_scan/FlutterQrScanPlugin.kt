// resources:
// - https://developer.android.com/reference/android/hardware/camera2/package-summary.html
// - https://www.youtube.com/watch?v=u38wOv2a_dA -> kotlin examples of the camera2 api

package io.cloudacy.flutter_qr_scan

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.view.Surface
import android.view.TextureView
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.ml.vision.FirebaseVision
import com.google.firebase.ml.vision.common.FirebaseVisionImage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.renderer.FlutterRenderer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

class FlutterQrScanPlugin: FlutterPlugin, ActivityAware, MethodCallHandler {
  // Needs to be an app-defined int constant. This value is the hex representation (first 8 digits) of "qrscan".
  // It defines the type of permission request. It will be used at the callback to check, which type of request it was.
  val cameraRequestId = 71727363

  val barcodeValueTypes = listOf("unknown", "contact", "email", "isbn", "phone", "product", "sms", "text", "url", "wifi", "geo", "event", "license")

  var cameraPermissionCallback: Runnable ?= null

  private var channel: MethodChannel ?= null
  private var activity: Activity ?= null
  private var renderer: FlutterRenderer ?= null
  private var cameraManager: CameraManager ?= null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    @Suppress("DEPRECATION")
    val channel = MethodChannel(flutterPluginBinding.flutterEngine.dartExecutor, "flutter_qr_scan")
    this.channel = channel
    @Suppress("DEPRECATION")
    this.renderer = flutterPluginBinding.flutterEngine.renderer
    channel.setMethodCallHandler(this)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.activity = binding.activity
    this.cameraManager = binding.activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  companion object {
    @JvmStatic
    @Suppress("UNUSED")
    fun registerWith(registrar: Registrar) {
      println("register")
      val channel = MethodChannel(registrar.messenger(), "flutter_qr_scan")
      val plugin = FlutterQrScanPlugin()
      plugin.channel = channel
      channel.setMethodCallHandler(plugin)
    }
  }

  inner class QrScanCameraPermissionRequestListener : PluginRegistry.RequestPermissionsResultListener {
    override fun onRequestPermissionsResult(requestId: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {
      // Check if the permission was set for this plugin.
      if (requestId == cameraRequestId) {
        // Execute the callback to continue to open the camera.
        cameraPermissionCallback?.run()
        return true
      }

      return false
    }
  }

  private fun checkCameraPermission(): Boolean {
    val activity = this.activity ?: return false

    return ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestCameraPermission(): Boolean {
    val activity = this.activity ?: return false

    // check if an explanation has to be shown

    //if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.CAMERA)) {
    // Show an explanation.

    // Request the permission.
    //} else {
    // No explanation required. We can now request the permission.

    //var permissionResult
    ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), cameraRequestId)
    //}

    return true
  }

  private fun openCamera(cameraId: String, result: Result) {
    val channel = this.channel
    if (channel == null) {
      result.error("ERR_CHANNEL_NOT_INITIALIZED", "The channel instance is not set!", null)
      return
    }

    val renderer = this.renderer
    if (renderer == null) {
      result.error("ERR_RENDERER_NOT_INITIALIZED", "The renderer instance is not set!", null)
      return
    }

    val cameraManager = this.cameraManager
    if (cameraManager == null) {
      result.error("ERR_CAMERA_MANAGER_NOT_INITIALIZED", "The cameraManager instance is not set!", null)
      return
    }

    val textureEntry = renderer.createSurfaceTexture()

    cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
      override fun onOpened(cameraDevice: CameraDevice) {
        try {
          // This surface is used for the preview.
          val surfaceTexture = textureEntry.surfaceTexture()
          // TODO: fix preview Size. See computeBestPreviewAndRecordingSize in camera plugin
          surfaceTexture.setDefaultBufferSize(100, 100)
          val previewSurface = Surface(surfaceTexture)

          // This surface is used for the qr-code detection.
          // Inspired by https://medium.com/@mt1729/an-android-journey-barcode-scanning-with-mobile-vision-api-and-camera2-part-1-8a97cc0d6747
          val imageReader = ImageReader.newInstance(100, 100, ImageFormat.YUV_420_888, 1)
          imageReader.setOnImageAvailableListener({ reader ->
            val image = imageReader.acquireNextImage()

            val detector = FirebaseVision.getInstance().visionBarcodeDetector
            val detectionTask = detector.detectInImage(FirebaseVisionImage.fromMediaImage(image, Surface.ROTATION_0))

            detectionTask.addOnCompleteListener { detections ->
              if (detections.result!!.isEmpty()) {
                return@addOnCompleteListener
              }

              val barcode = detections.result!![0]
              channel.invokeMethod("code", mapOf(
                "type" to barcodeValueTypes[barcode.valueType - 1],
                "value" to barcode.rawValue
              ))

              // As soon as a code was detected, close the camera.
              cameraDevice.close()
              textureEntry.release()
              reader.close()
            }

            image.close()
          }, null)

          cameraDevice.createCaptureSession(listOf(previewSurface, imageReader.surface), object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(cameraCaptureSession: CameraCaptureSession) {
              if (cameraDevice == null) {
                result.error("QrScanCameraClosed", "The camera was closed during the configuration.", null)
              }

              try {
                val captureRequestBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)

                captureRequestBuilder.addTarget(previewSurface)
                captureRequestBuilder.addTarget(imageReader.surface)

                // Optional. (auto-exposure, auto-white-balance, auto-focus)
                captureRequestBuilder.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)

                cameraCaptureSession.setRepeatingRequest(captureRequestBuilder.build(), null, null)

                result.success(mapOf(
                  "textureId" to textureEntry.id(),
                  "previewWidth" to 100,
                  "previewHeight" to 100
                ))
              } catch (e: Exception) {
                result.error("QrScanCapture", e.message, null)
              }
            }

            override fun onConfigureFailed(cameraCaptureSession: CameraCaptureSession) {
              result.error("QrScanCaptureConfig", "", null)
            }
          }, null)
        } catch (e: Exception) {
          result.error("QrScanOpen", e.message, null)
          cameraDevice.close()
        }
      }

      override fun onClosed(camera: CameraDevice) {
        channel.invokeMethod("cameraClosed", null)

        super.onClosed(camera)
      }

      override fun onDisconnected(cameraDevice: CameraDevice) {
        cameraDevice.close()

        channel.invokeMethod("cameraClosed", null)
      }

      override fun onError(cameraDevice: CameraDevice, errorCode: Int) {
        cameraDevice.close()

        when (errorCode) {
          ERROR_CAMERA_IN_USE -> result.error("QrScanError", "Camera in use", null)
          ERROR_MAX_CAMERAS_IN_USE -> result.error("QrScanError", "Maximum cameras in use", null)
          ERROR_CAMERA_DISABLED -> result.error("QrScanError", "Camera disabled", null)
          ERROR_CAMERA_DEVICE -> result.error("QrScanError", "Camera device error", null)
          ERROR_CAMERA_SERVICE -> result.error("QrScanError", "Camera service error", null)
        }
      }
    }, null)
  }

  private fun initialize(call: MethodCall, result: Result) {
    val cameraId = call.argument<String>("cameraId")

    if (cameraId == null) {
      result.error("QRInvalidCameraId", "Argument 'cameraId' not defined!", null)
      return
    }

    // Check if we have permission to use the camera.
    // If so, we open the camera directly.
    // If not, we request the permission of the camera.
    if (checkCameraPermission()) {
      openCamera(cameraId, result)
    } else {
      // Prepare the permissionResultCheck callback.
      cameraPermissionCallback = object : Runnable {
        override fun run() {
          // Unset the runnable to make sure it is not executed twice.
          cameraPermissionCallback = null

          // Check if the permission was granted.
          // If the permission is still not granted, the user denied the permission and we have to abort here.
          if (!checkCameraPermission()) {
            result.error("QRPermissionDenied", "The camera permission was not granted!", null)
            return
          }

          openCamera(cameraId, result)
        }
      }

      requestCameraPermission()
    }
  }

  private fun getAvailableCameras(result: Result) {
    // Check if we have permission to use the camera.
    // If so, we continue.
    // If not, we request the permission to access the camera list.
    if (!checkCameraPermission()) {
      // Prepare the permissionResultCheck callback.
      cameraPermissionCallback = object : Runnable {
        override fun run() {
          // Unset the runnable to make sure it is not executed twice.
          cameraPermissionCallback = null

          // Check if the permission was granted.
          // If the permission is still not granted, the user denied the permission and we have to abort here.
          if (!checkCameraPermission()) {
            result.error("QRPermissionDenied", "The camera permission was not granted!", null)
            return
          }

          getAvailableCameras(result)
        }
      }

      requestCameraPermission()
      return
    }

    val cameraManager = this.cameraManager
    if (cameraManager == null) {
      result.error("ERR_CAMERA_MANAGER_NOT_INITIALIZED", "The cameraManager instance is not set!", null)
      return
    }

    try {
      val cameraIds = cameraManager.cameraIdList
      val cameras = mutableListOf<Map<String, Any>>()

      for (cameraId in cameraIds) {
        val cameraDetails = mutableMapOf<String, Any>()
        val cameraCharacteristics = cameraManager.getCameraCharacteristics(cameraId)

        cameraDetails["id"] = cameraId
        cameraDetails["orientation"] = cameraCharacteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) as Any

        when (cameraCharacteristics.get(CameraCharacteristics.LENS_FACING)) {
          CameraMetadata.LENS_FACING_FRONT -> cameraDetails["lensFacing"] = "front"
          CameraMetadata.LENS_FACING_BACK -> cameraDetails["lensFacing"] = "back"
          CameraMetadata.LENS_FACING_EXTERNAL -> cameraDetails["lensFacing"] = "external"
        }

        cameras.add(cameraDetails)
      }

      result.success(cameras)
    } catch (e: Exception) {
      result.error("QrScanAccess", e.message, null)
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "initialize" -> {
        initialize(call, result)
      }
      "availableCameras" -> {
        getAvailableCameras(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }

  override fun onDetachedFromActivity() {
  }

  override fun onDetachedFromActivityForConfigChanges() {
  }
}
