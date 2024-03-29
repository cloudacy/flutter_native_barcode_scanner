package io.cloudacy.flutter_native_barcode_scanner

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Rect
import android.view.Surface
import androidx.annotation.NonNull
import androidx.camera.core.AspectRatio
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.absoluteValue
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/** FlutterNativeBarcodeScannerPlugin */
class FlutterNativeBarcodeScannerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var activity : Activity? = null
  private lateinit var textureRegistry : TextureRegistry

  // Needs to be an app-defined int constant. This value is the hex representation of "BS".
  // It only uses 16 bits to meet requirements (android.support.v4.app.FragmentActivity).
  // It defines the type of permission request. It will be used at the callback to check, which type of request it was.
  private val cameraPermissionRequestCode = 0x4253

  private var scanFrame: List<Double>? = null

  private var requestCameraPermissionResult: Result? = null

  private var cameraProvider: ProcessCameraProvider? = null
  private var cameraExecutor: ExecutorService? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_native_barcode_scanner")
    channel.setMethodCallHandler(this)

    textureRegistry = flutterPluginBinding.textureRegistry
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity

    // register this class as a RequestPermissionResultListener such that onRequestPermissionResult will be called.
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity

    // register this class as a RequestPermissionResultListener such that onRequestPermissionResult will be called.
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null

    // stop all use cases for this plugin.
    cameraProvider?.unbindAll()
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == cameraPermissionRequestCode) {
      if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        val requestCameraPermissionResult = requestCameraPermissionResult ?: return false
        start(requestCameraPermissionResult)
        return true
      }
    }
    return false
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "start" -> {
        if (call.hasArgument("scanFrame")) {
          scanFrame = call.argument<List<Double>>("scanFrame")
        }

        start(result)
      }
      "stop" -> {
        stop(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private class BarcodeAnalyzer(private val listener: (List<Barcode>, Int, Int) -> Unit) : ImageAnalysis.Analyzer {
    private val barcodeScanner: BarcodeScanner = BarcodeScanning.getClient()

    @SuppressLint("UnsafeOptInUsageError")
    override fun analyze(imageProxy: ImageProxy) {
      val mediaImage = imageProxy.image ?: return
      val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

      barcodeScanner.process(image)
        .addOnSuccessListener {
          if (it.isNotEmpty()) {
            val angle = imageProxy.imageInfo.rotationDegrees.toDouble() / 180 * Math.PI
            val width = (image.width.toDouble() * cos(angle) - image.height.toDouble() * sin(angle)).roundToInt().absoluteValue
            val height = (image.width.toDouble() * sin(angle) + image.height.toDouble() * cos(angle)).roundToInt().absoluteValue
            listener(it, width, height)
          }
          imageProxy.close()
        }
        .addOnFailureListener {
          imageProxy.close()
        }
        .addOnCanceledListener {
          imageProxy.close()
        }
    }
  }

  private fun start(result: Result): String {
    if (!checkCameraPermission()) {
      // store the current result object for later use. (when user accepted or denied access)
      requestCameraPermissionResult = result
      requestCameraPermission()

      return "WAITING_FOR_PERMISSION"
    }

    if (requestCameraPermissionResult != null) {
      requestCameraPermissionResult = null
    }

    cameraExecutor = Executors.newSingleThreadExecutor()

    startCamera(result)

    return "INITIALIZED"
  }

  private fun stop(result: Result) {
    // stop all use cases for this plugin
    cameraProvider?.unbindAll()

    // stop the cameraExecutor
    cameraExecutor?.shutdown()

    result.success(true)
  }

  private fun checkCameraPermission(): Boolean {
    val activity = this.activity ?: return false
    return ContextCompat.checkSelfPermission(activity.baseContext, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestCameraPermission(): Boolean {
    val activity = this.activity ?: return false
    ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), cameraPermissionRequestCode)
    return true
  }

  @SuppressLint("RestrictedApi")
  private fun startCamera(result: Result) {
    val activity = activity ?: return
    val cameraExecutor = cameraExecutor ?: return

    val cameraProviderFuture = ProcessCameraProvider.getInstance(activity.baseContext)

    cameraProviderFuture.addListener(Runnable {
      // Used to bind the lifecycle of cameras to the lifecycle owner
      val cameraProvider = cameraProviderFuture.get()
      this.cameraProvider = cameraProvider

      // Create a surface texture
      val surfaceTextureEntry = textureRegistry.createSurfaceTexture()
      val surfaceTexture = surfaceTextureEntry.surfaceTexture()

      // Preview
      val preview = Preview.Builder()
        .setTargetAspectRatio(AspectRatio.RATIO_4_3)
        .build()
        .also {
          it.setSurfaceProvider {
            val resolution = it.resolution
            surfaceTexture.setDefaultBufferSize(resolution.width, resolution.height)
            val surface = Surface(surfaceTexture)
            it.provideSurface(surface, ContextCompat.getMainExecutor(activity.baseContext), {})
          }
        }

      // Barcode analyzer
      val barcodeAnalyzer = ImageAnalysis.Builder()
        .build()
        .also {
          it.setAnalyzer(cameraExecutor, BarcodeAnalyzer { barcodes, imageWidth, imageHeight ->
            if (scanFrame == null) {
              channel.invokeMethod("code", barcodes[0].rawValue)
              return@BarcodeAnalyzer
            }

            val halfWidth = imageWidth / 2
            val halfHeight = imageHeight / 2
            val halfWidthOffset = (halfWidth.toDouble() * scanFrame!![0]).roundToInt()
            val halfHeightOffset = (halfHeight.toDouble() * scanFrame!![1]).roundToInt()
            val frameBoundingBox = Rect(
              halfWidth - halfWidthOffset,
              halfHeight - halfHeightOffset,
              halfWidth + halfWidthOffset,
              halfHeight + halfHeightOffset
            )

            for (barcode in barcodes) {
              val bb = barcode.boundingBox ?: continue
              if (frameBoundingBox.contains(bb)) {
                channel.invokeMethod("code", barcode.rawValue)
                break
              }
            }
          })
        }

      // Select back camera as a default
      val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

      try {
        // Unbind use cases before rebinding
        cameraProvider.unbindAll()

        // Bind use cases to camera
        cameraProvider.bindToLifecycle(activity as LifecycleOwner, cameraSelector, preview, barcodeAnalyzer)
      } catch(e: Exception) {
        result.error("USE_CASE_BIND_FAILED", "Unable to bind use cases to the camera", e)
        return@Runnable
      }

      result.success(mapOf(
        "textureId" to surfaceTextureEntry.id(),
        "previewWidth" to preview.attachedSurfaceResolution?.width,
        "previewHeight" to preview.attachedSurfaceResolution?.height
      ))
    }, ContextCompat.getMainExecutor(activity.baseContext))
  }
}
