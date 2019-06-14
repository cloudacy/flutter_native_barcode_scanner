package io.cloudacy.qr_scan

import java.lang.Exception

import android.content.Context
import android.os.Build

import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraMetadata

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

import io.flutter.view.FlutterView

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
        cameraManager.openCamera(call.argument("cameraId") as String, CameraDevice.StateCallback() {
          
        }, null)


        val texture = view.createSurfaceTexture()

        System.out.println("test")
        result.success("Texture ${texture.id()}")
      }
      else -> {
        result.notImplemented()
      }
    }
  }
}
