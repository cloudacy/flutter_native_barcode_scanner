import Flutter
import UIKit
import AVFoundation

public enum FLNativeBarcodeScannerError : Error {
  case access
  case noVideoDevice
  case noVideoDeviceInput
}

public class FLNativeBarcodeScannerCamera:
  NSObject,
  AVCaptureVideoDataOutputSampleBufferDelegate,
  AVCaptureMetadataOutputObjectsDelegate,
  FlutterTexture
{
  public  let captureSession = AVCaptureSession()
  
  private let quality = AVCaptureSession.Preset.hd1280x720
  private var pixelBuffer: CVPixelBuffer?
  
  public  var previewSize = CGSize(width: 1280, height: 720)
  public  var onFrameAvailable: (() -> Void)?
  public  var methodChannel: FlutterMethodChannel?
  
  private let videoOutput = AVCaptureVideoDataOutput()
  private let metadataOutput = AVCaptureMetadataOutput()
  private let feedbackGenerator = UINotificationFeedbackGenerator()
  
  private let queue = DispatchQueue(label: "io.cloudacy.flutter_native_barcode_scanner")
  
  public init(methodChannel: FlutterMethodChannel) {
    self.methodChannel = methodChannel
    
    super.init()
    
    videoOutput.setSampleBufferDelegate(self, queue: queue)
  }
  
  public func startScanning(
    completion: @escaping (Result<Bool, FLNativeBarcodeScannerError>) -> Void
  ) {
    // request access
    AVCaptureDevice.requestAccess(for: .video) { (granted) in
      if (granted) {
        let configureSessionResult = self.configureSession()
        switch configureSessionResult {
        case .failure(_):
          completion(configureSessionResult)
          break
        case .success(_):
          self.captureSession.startRunning()
          completion(configureSessionResult)
          break
        }
      } else {
        completion(.failure(.access))
      }
    }
  }
  
  private func configureSession() -> Result<Bool, FLNativeBarcodeScannerError> {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = quality
    
    guard let videoDevice = AVCaptureDevice.default(for: .video) else {
      captureSession.commitConfiguration()
      return .failure(.noVideoDevice)
    }
    
    guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
      captureSession.commitConfiguration()
      return .failure(.noVideoDeviceInput)
    }
    
    if captureSession.canAddInput(videoDeviceInput) {
      captureSession.addInput(videoDeviceInput)
    }
    
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
      
      // Set video orientation to portrait.
      if let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) {
        connection.videoOrientation = .portrait
      }
    }
    
    if captureSession.canAddOutput(metadataOutput) {
      captureSession.addOutput(metadataOutput)
    }
    
    // Define supported barcodes.
    metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
    metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .code39, .code39Mod43, .code93, .code128, .pdf417, .itf14, .upce, .dataMatrix]
    
    captureSession.commitConfiguration()
    
    let dims = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
    previewSize = CGSize(width: CGFloat(dims.width), height: CGFloat(dims.height))
    
    return .success(true)
  }
  
  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    
    onFrameAvailable?()
  }
  
  public func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
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

public class FLNativeBarcodeScanner: NSObject, FlutterPlugin {
  private let registry: FlutterTextureRegistry
  private let messenger: FlutterBinaryMessenger
  private let methodChannel: FlutterMethodChannel
  
  private let cam: FLNativeBarcodeScannerCamera
  
  init(
    registry: FlutterTextureRegistry,
    messenger: FlutterBinaryMessenger,
    methodChannel: FlutterMethodChannel
  ) {
    self.registry = registry
    self.messenger = messenger
    self.methodChannel = methodChannel
    self.cam = FLNativeBarcodeScannerCamera(methodChannel: methodChannel)
  }
  
  public class func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_native_barcode_scanner", binaryMessenger: registrar.messenger())
    let instance = FLNativeBarcodeScanner(registry: registrar.textures(), messenger: registrar.messenger(), methodChannel: channel)
    
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      initializeScanner(call: call, result: result)
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
  
  public func registerTexture() -> [String : Any] {
    let textureId = self.registry.register(self.cam)
    
    self.cam.onFrameAvailable = {
      self.registry.textureFrameAvailable(textureId)
    }
    
    return [
      "textureId": textureId,
      "previewWidth": self.cam.previewSize.width,
      "previewHeight": self.cam.previewSize.height
    ]
  }
  
  public func initializeScanner(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
    self.cam.startScanning() { r in
      switch r {
      case .failure(let error):
        switch error {
        case .access:
          result(FlutterError(code: "NoDeviceAccess", message: "The user didn't allow access to the capture device!", details: nil))
          break
        case .noVideoDevice:
          result(FlutterError(code: "NoVideoDevice", message: "This device doesn't provide a VideoDevice!", details: nil))
          break
        case .noVideoDeviceInput:
          result(FlutterError(code: "NoVideoDeviceInput", message: "This device doesn't provide a VideoDeviceInput!", details: nil))
          break
        }
        break
      case .success(_):
        result(self.registerTexture())
        break
      }
    }
  }
}

private func getFlutterError(error: Error?) -> FlutterError? {
  return FlutterError(code: "Error", message: (error as NSError?)?.domain, details: error?.localizedDescription)
}
