// resources:
// - https://developer.android.com/reference/android/hardware/camera2/package-summary.html
// - https://www.youtube.com/watch?v=u38wOv2a_dA -> kotlin examples of the camera2 api

package io.cloudacy.qr_scan

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.view.Surface
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.ml.vision.FirebaseVision
import com.google.firebase.ml.vision.common.FirebaseVisionImage
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.FlutterView

class QrScanPlugin : MethodCallHandler {
  private val registrar: Registrar
  private val activity: Activity
  private val view: FlutterView
  private val cameraManager: CameraManager

  private val channel: MethodChannel

  var cameraPermissionCallback: Runnable ?= null

  constructor(registrar: Registrar, channel: MethodChannel) {
    this.registrar = registrar
    this.view = registrar.view()
    this.activity = registrar.activity()
    this.cameraManager = this.activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager

    this.channel = channel

    // Add our permissionRequestListener.
    registrar.addRequestPermissionsResultListener(QrScanCameraPermissionRequestListener())
  }

  // Static variables and methods.
  companion object {
    // Needs to be an app-defined int constant. This value is the hex representation (first 8 digits) of "qrscan".
    // It defines the type of permission request. It will be used at the callback to check, which type of request it was.
    const val CAMERA_REQUEST_ID = 71727363

    val barcodeValueTypes = listOf("unknown", "contact", "email", "isbn", "phone", "product", "sms", "text", "url", "wifi", "geo", "event", "license")

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      // Prepare the method-channel and initialize the plugin.
      val channel = MethodChannel(registrar.messenger(), "io.cloudacy.qr_scan")
      channel.setMethodCallHandler(QrScanPlugin(registrar, channel))
    }
  }

  inner class QrScanCameraPermissionRequestListener : RequestPermissionsResultListener {
    override fun onRequestPermissionsResult(requestId: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {
      // Check if the permission was set for this plugin.
      if (requestId == CAMERA_REQUEST_ID) {
        // Execute the callback to continue to open the camera.
        cameraPermissionCallback?.run()
        return true
      }

      return false
    }
  }

  private fun checkCameraPermission(): Boolean {
    return ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestCameraPermission() {
    // check if an explanation has to be shown

    //if (ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.CAMERA)) {
      // Show an explanation.

      // Request the permission.
    //} else {
      // No explanation required. We can now request the permission.

      //var permissionResult
      ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST_ID)
    //}
  }

  private fun openCamera(cameraId: String, result: Result) {
    val textureEntry = view.createSurfaceTexture()

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
          imageReader.setOnImageAvailableListener({
            val image = imageReader.acquireNextImage()

            val detector = FirebaseVision.getInstance().visionBarcodeDetector
            val detectionTask = detector.detectInImage(FirebaseVisionImage.fromMediaImage(image, Surface.ROTATION_0))

            detectionTask.addOnCompleteListener { detections ->
              if (detections.result!!.isEmpty()) {
                println("No Barcode detected.")
                return@addOnCompleteListener
              }

              val barcode = detections.result!![0]
              println("Barcode detected")
              channel.invokeMethod("code", mapOf(
                "type" to barcodeValueTypes[barcode.valueType - 1],
                "value" to barcode.rawValue
              ))
            }

            image.close()
          }, null)

          cameraDevice.createCaptureSession(listOf(previewSurface, imageReader.surface), object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(cameraCaptureSession: CameraCaptureSession) {
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

    // Check if we have permission to use the camera.
    // If so, we open the camera directly.
    // If not, we request the permission of the camera.
    if (checkCameraPermission()) {
      openCamera(cameraId, result)
    } else {
      requestCameraPermission()
    }
  }

  private fun getAvailableCameras(result: Result) {
    try {
      val cameraIds = cameraManager.cameraIdList
      val cameras = mutableListOf<Map<String, Any>>()

      for (cameraId in cameraIds) {
        val cameraDetails = mutableMapOf<String, Any>()
        val cameraCharacteristics = cameraManager.getCameraCharacteristics(cameraId)

        cameraDetails["id"] = cameraId
        cameraDetails["orientation"] = cameraCharacteristics.get(CameraCharacteristics.SENSOR_ORIENTATION)

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

  override fun onMethodCall(call: MethodCall, result: Result) {
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
}
