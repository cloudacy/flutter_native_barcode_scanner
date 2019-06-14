package io.cloudacy.qr_scan

import kotlin.Exception

import android.content.Context
import android.graphics.SurfaceTexture
import android.os.Build

import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraMetadata
import android.view.Surface

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

import io.flutter.view.FlutterView
import io.flutter.view.TextureRegistry

class QrScanCameraStateCallback : CameraDevice.StateCallback() {
  private val surfaceTextureEntry: TextureRegistry.SurfaceTextureEntry

  constructor(surfaceTextureEntry: TextureRegistry.SurfaceTextureEntry) {
    this.surfaceTextureEntry = surfaceTextureEntry
  }

  override fun onOpened(cameraDevice: CameraDevice) {
    try {
      val surfaceTexture = surfaceTextureEntry.surfaceTexture()
      // TODO: fix preview Size. See computeBestPreviewAndRecordingSize in camera plugin
      surfaceTexture.setDefaultBufferSize(100, 100)
      cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)

      val surfaces = mutableListOf<Surface>()


    } catch (e: Exception) {
      System.err.println(e.message)
      cameraDevice.close()
    }
  }

  override fun onClosed(cameraDevice: CameraDevice) {
    System.out.println("Camera closed")
  }

  override fun onDisconnected(cameraDevice: CameraDevice) {
    System.out.println("Camera disconnected")
  }

  override fun onError(cameraDevice: CameraDevice, errorCode: Int) {
    cameraDevice.close()

    when (errorCode) {
      ERROR_CAMERA_IN_USE -> System.err.println("Camera in use")
      ERROR_MAX_CAMERAS_IN_USE -> System.err.println("Maximum cameras in use")
      ERROR_CAMERA_DISABLED -> System.err.println("Camera disabled")
      ERROR_CAMERA_DEVICE -> System.err.println("Camera device error")
      ERROR_CAMERA_SERVICE -> System.err.println("Camera service error")
    }
  }
}

class QrScanPlugin: MethodCallHandler {
  private val view: FlutterView

  constructor(view: FlutterView) {
    this.view = view
  }

  companion object {
    private var cameraManager: CameraManager ?= null

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      // Only Android > SDK 21 supported.
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
        return
      }

      cameraManager = registrar.activity().getSystemService(Context.CAMERA_SERVICE) as CameraManager?

      val channel = MethodChannel(registrar.messenger(), "io.cloudacy.qr_scan")
      channel.setMethodCallHandler(QrScanPlugin(registrar.view()))
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "availableCameras" -> {
        try {
          val cameraIds = cameraManager!!.cameraIdList
          val cameras = mutableListOf<Map<String, Any>>()

          for (cameraId in cameraIds) {
            var cameraDetails = mutableMapOf<String, Any>()
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
      "init" -> {
        val flutterTextureEntry = view.createSurfaceTexture()

        cameraManager!!.openCamera(call.argument("cameraId"), QrScanCameraStateCallback(flutterTextureEntry), null)


        System.out.println("test")
      }
      else -> {
        result.notImplemented()
      }
    }
  }
}
