import Flutter
import UIKit
import AVFoundation
import CoreMotion
import libkern

@available(iOS 10.0, *)
public class QrCam: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, FlutterTexture {
  public let captureSession = AVCaptureSession()
  
  private let quality = AVCaptureSession.Preset.medium
  private var pixelBuffer: CVPixelBuffer?
  
  private(set) var previewSize = CGSize(width: 1920, height: 1080)
  var onFrameAvailable: (() -> Void)?
  var methodChannel: FlutterMethodChannel?
  
  private var videoOutput = AVCaptureVideoDataOutput()
  private var metadataOutput = AVCaptureMetadataOutput()
  private var feedbackGenerator = UINotificationFeedbackGenerator()
  
  private var queue = DispatchQueue(label: "io.cloudacy.flutter_qr_scan")
  
  public init(methodChannel: FlutterMethodChannel) {
    super.init()
    
    self.methodChannel = methodChannel
  }
  
  public func startScanning() {
    // request access
    AVCaptureDevice.requestAccess(for: .video) { (granted) in
      if (granted) {
        self.configureSession()
        self.captureSession.startRunning()
      } else {
        // TODO: send error when no access to the camera was granted
      }
    }
  }
  
  private func configureSession() {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = quality
    guard let videoDevice = AVCaptureDevice.default(for: .video) else {return}
    guard
      let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
      captureSession.canAddInput(videoDeviceInput)
    else { return }
    captureSession.addInput(videoDeviceInput)
  
    videoOutput.setSampleBufferDelegate(self, queue: queue)
    guard captureSession.canAddOutput(videoOutput) else { return }
    captureSession.addOutput(videoOutput)
    captureSession.addOutput(metadataOutput)
    
    // configure metadataOutput
    
    // support qr codes
    metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
    metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .code39, .code93, .code128, .pdf417, .upce, .dataMatrix]
    captureSession.commitConfiguration()
    
    // fix orientation
    guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
    connection.videoOrientation = .portrait
  }

  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    
    if onFrameAvailable != nil {
      onFrameAvailable?()
    }
  }

  public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    if let metadataObject = metadataObjects.first {
      guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
      guard let stringValue = readableObject.stringValue else { return }
      
      // we can only do this in main thread
      DispatchQueue.main.async {
        // haptic feedback (vibrate)
        self.feedbackGenerator.prepare()
        self.feedbackGenerator.notificationOccurred(.success)
      }
      
      methodChannel?.invokeMethod("code", arguments: stringValue)
    }
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    if self.pixelBuffer == nil {
      return nil
    }
    
    return Unmanaged.passRetained(self.pixelBuffer!)
  }
}

@available(iOS 10.0, *)
public class SwiftFlutterQrScanPlugin: NSObject, FlutterPlugin {
  private(set) var registry: FlutterTextureRegistry
  private(set) var messenger: FlutterBinaryMessenger
  private(set) var methodChannel: FlutterMethodChannel
  
  private(set) var cam: QrCam

  init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger, methodChannel: FlutterMethodChannel) {
    self.registry = registry
    self.messenger = messenger
    self.methodChannel = methodChannel
    self.cam = QrCam(methodChannel: methodChannel)
  }
  
  public class func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_qr_scan", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterQrScanPlugin(registry: registrar.textures(), messenger: registrar.messenger(), methodChannel: channel)
    
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      initializeQrScanner(call: call, result: result)
      break
    case "stop":
      cam.captureSession.stopRunning()
      result(true)
      break
    default:
      result(FlutterError(code: "InvalidMethod", message: "Invalid method \(call.method)!", details: nil))
      break
    }
  }

  public func initializeQrScanner(call: FlutterMethodCall, result: FlutterResult) -> Void {
    cam.startScanning()
    
    let textureId = registry.register(cam)
    
    cam.onFrameAvailable = {
      self.registry.textureFrameAvailable(textureId)
    }
    
    let resultObject = [
      "textureId": textureId,
      "previewWidth": cam.previewSize.width,
      "previewHeight": cam.previewSize.height
    ] as [String : Any]
    
    result(resultObject)
  }
}

private func getFlutterError(error: Error?) -> FlutterError? {
    return FlutterError(code: "Error", message: (error as NSError?)?.domain, details: error?.localizedDescription)
}
