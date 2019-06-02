import Flutter
import UIKit
import AVFoundation

public class SwiftQrScanPluginTexture: NSObject, FlutterTexture {
  private(set) var latestPixelBuffer: CVPixelBuffer?
  var onFrameAvailable: (() -> Void)?
  
  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    var pixelBuffer = latestPixelBuffer
    var ptr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(&latestPixelBuffer)
    let ptr2: UnsafeMutablePointer<UnsafeMutableRawPointer?> = UnsafeMutablePointer(&ptr)
    while !OSAtomicCompareAndSwapPtrBarrier(&pixelBuffer, nil, ptr2) {
      pixelBuffer = latestPixelBuffer
    }
    return Unmanaged<CVPixelBuffer>.passRetained(latestPixelBuffer!)
  }
}

public class SwiftQrScanPlugin: NSObject, FlutterPlugin {
  private(set) var textureRegistry: FlutterTextureRegistry? = nil
  
  private(set) var flutterResult: FlutterResult? = nil
  private(set) var captureSession: AVCaptureSession? = nil
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "io.cloudacy.qr_scan", binaryMessenger: registrar.messenger())
    let instance = SwiftQrScanPlugin()
    instance.textureRegistry = registrar.textures()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    flutterResult = result
    
    switch call.method {
    case "init":
      initializeQrScanner()
      break
    case "start":
      startQrScanner()
      break
    default:
      result(FlutterError(code: "InvalidMethod", message: "Invalid method \(call.method)!", details: nil))
      break
    }
  }
  
  public func initializeQrScanner() {
    guard let flutterResult = flutterResult else {
      print("ERROR: No flutterResult available!")
      return
    }
    
    let texture = SwiftQrScanPluginTexture()
    let _textureId = textureRegistry?.register(texture)
    
    guard let textureId = _textureId else {
      flutterResult(FlutterError(code: "NoTextureId", message: "Unable to fetch the textureId!", details: nil))
      return
    }
    
    // Camera test
    self.captureSession = AVCaptureSession()
    // Begin/Commit configuration allows atomic configuration changes
    guard let captureSession = self.captureSession else {
      flutterResult(FlutterError(code: "NoCaptureSession", message: "Unable to create a capture session!", details: nil))
      return
    }
    captureSession.beginConfiguration()
    
    // Try to find a camera device.
    guard let cameraDevice = findCameraDevice() else {
      flutterResult(FlutterError(code: "NoCameraFound", message: "No camera device found!", details: nil))
      return
    }
//    cameraDevice.activeVideoMinFrameDuration = CMTime(seconds: 1.0, preferredTimescale: 1)
    
    // Try to set the found camera device as an input.
    guard let cameraDeviceInput = try? AVCaptureDeviceInput(device: cameraDevice), captureSession.canAddInput(cameraDeviceInput) else {
      flutterResult(FlutterError(code: "NoCameraInput", message: "Unable to use the camera device as an input!", details: nil))
      return
    }
    
    // Add the input to the captureSession.
    captureSession.addInput(cameraDeviceInput)
    
    // Create an output.
    // https://medium.com/@abhimuralidharan/how-to-create-a-simple-qrcode-barcode-scanner-app-in-ios-swift-fd9970a70859
    let metadataOutput = AVCaptureMetadataOutput()
    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
//    metadataOutput.metadataObjectTypes = [.qr]
    
    captureSession.commitConfiguration()
    
    texture.onFrameAvailable = {() -> Void in
      self.textureRegistry?.textureFrameAvailable(textureId)
    }
    
    flutterResult([
      "textureId": textureId
    ])
  }
  
  public func startQrScanner() {
    guard let flutterResult = self.flutterResult else {
      print("ERROR: No flutterResult available!")
      return
    }
    
    guard let captureSession = captureSession else {
      flutterResult(FlutterError(code: "NoCaptureSession", message: "Unable to create a capture session!", details: nil))
      return
    }
    
    // Start scanning for a QR code.
    captureSession.startRunning()
  }

  public func findCameraDevice() -> AVCaptureDevice? {
    var cameraDevice: AVCaptureDevice?
    if #available(iOS 10.0, *) {
      cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    } else {
      // Fallback on earlier versions.
      let videoDevices = AVCaptureDevice.devices(for: .video)
      if videoDevices.count > 0 {
        cameraDevice = videoDevices.first
      }
    }
    return cameraDevice
  }
}

extension SwiftQrScanPlugin: AVCaptureMetadataOutputObjectsDelegate {
  public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    if let metadataObject = metadataObjects.first {
      guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
        return
      }
      guard let stringValue = readableObject.stringValue else {
        return
      }
      // Stop scanning for more QR codes.
      if let captureSession = self.captureSession {
        captureSession.stopRunning()
      }
      // Send the result back.
      print(stringValue)
      if let result = self.flutterResult {
        result(stringValue)
      }
    }
  }
}
