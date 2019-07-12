// resources:
// - https://developer.android.com/reference/android/hardware/camera2/package-summary.html
// - https://www.youtube.com/watch?v=u38wOv2a_dA -> kotlin examples of the camera2 api

package io.cloudacy.qr_scan

import kotlin.Exception

import android.content.Context
import android.hardware.camera2.*

import android.view.Surface

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

import io.flutter.view.FlutterView

class QrScanPlugin : MethodCallHandler {
  private val view: FlutterView

  constructor(view: FlutterView) {
    this.view = view
  }

  companion object {
    private var cameraManager: CameraManager ?= null

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      cameraManager = registrar.activity().getSystemService(Context.CAMERA_SERVICE) as CameraManager?

      val channel = MethodChannel(registrar.messenger(), "io.cloudacy.qr_scan")
      channel.setMethodCallHandler(QrScanPlugin(registrar.view()))
    }
  }

  private fun initialize(call: MethodCall, result: Result) {
    val textureEntry = view.createSurfaceTexture()
    val cameraId = call.argument<String>("cameraId") ?: return

    cameraManager!!.openCamera(cameraId, object : CameraDevice.StateCallback() {
      override fun onOpened(cameraDevice: CameraDevice) {
        try {
          val surfaceTexture = textureEntry.surfaceTexture()
          // TODO: fix preview Size. See computeBestPreviewAndRecordingSize in camera plugin
          surfaceTexture.setDefaultBufferSize(100, 100)
          val captureRequestBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)

          val surfaces = mutableListOf<Surface>()

          val previewSurface = Surface(surfaceTexture)
          surfaces.add(previewSurface)
          captureRequestBuilder.addTarget(previewSurface)

          cameraDevice.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(cameraCaptureSession: CameraCaptureSession) {
              try {
                // Check if the camera is still active
                //if (cameraDevice == null) {
                //  result.error("QrScanClosed", "The camera was already closed again.", null)
                //  return
                //}

                captureRequestBuilder.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                cameraCaptureSession.setRepeatingRequest(captureRequestBuilder.build(), null, null)
                result.success(null)
              } catch (e: Exception) {
                result.error("QrScanOpen", e.message, null)
              }
            }

            override fun onConfigureFailed(cameraCaptureSession: CameraCaptureSession) {
              result.error("QrScanConfig", "", null)
            }
          }, null)
        } catch (e: Exception) {
          result.error("QrScanPreview", e.message, null)
          cameraDevice.close()
        }

        result.success(mapOf(
          "textureId" to textureEntry.id(),
          "previewWidth" to 100,
          "previewHeight" to 100
        ))
      }

      override fun onClosed(cameraDevice: CameraDevice) {
        super.onClosed(cameraDevice)
        result.error("QrScanClosed", "The camera was closed.", null)
      }

      override fun onDisconnected(cameraDevice: CameraDevice) {
        cameraDevice.close()
        result.error("QrScanDisconnected", "The camera accidentally disconnected.", null)
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

    println("opened camera")
  }

  private fun getAvailableCameras(result: Result) {
    try {
      val cameraIds = cameraManager!!.cameraIdList
      val cameras = mutableListOf<Map<String, Any>>()

      for (cameraId in cameraIds) {
        val cameraDetails = mutableMapOf<String, Any>()
        val cameraCharacteristics = cameraManager!!.getCameraCharacteristics(cameraId)

        cameraDetails["id"] = cameraId
        cameraDetails["orientation"] = cameraCharacteristics.get(CameraCharacteristics.SENSOR_ORIENTATION)

        when (cameraCharacteristics.get(CameraCharacteristics.LENS_FACING)) {
          CameraMetadata.LENS_FACING_FRONT -> cameraDetails["location"] = "front"
          CameraMetadata.LENS_FACING_BACK -> cameraDetails["location"] = "back"
          CameraMetadata.LENS_FACING_EXTERNAL -> cameraDetails["location"] = "external"
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
      "init" -> {
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
