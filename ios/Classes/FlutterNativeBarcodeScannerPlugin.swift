import Flutter
import UIKit
import AVFoundation

public enum FlutterNativeBarcodeScannerError : Error {
  case access
  case noVideoDevice
  case noVideoDeviceInput
}

let FlutterNativeBarcodeScannerFormats : [String: AVMetadataObject.ObjectType] = [
  "aztec": .aztec,
  "code39": .code39,
  "code93": .code93,
  "code128": .code128,
  "dataMatrix": .dataMatrix,
  "ean8": .ean8,
  "ean13": .ean13,
  "itf": .itf14,
  "pdf417": .pdf417,
  "qr": .qr,
  "upce": .upce
]

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
    formats: [AVMetadataObject.ObjectType],
    scanFrame: [Double]?,
    completion: @escaping (Result<Bool, FlutterNativeBarcodeScannerError>) -> Void
  ) {
    // request access
    AVCaptureDevice.requestAccess(for: .video) { (granted) in
      if (granted) {
        let configureSessionResult = self.configureSession(formats: formats, scanFrame: scanFrame)
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
  
  private func configureSession(
    formats: [AVMetadataObject.ObjectType],
    scanFrame: [Double]?
  ) -> Result<Bool, FlutterNativeBarcodeScannerError> {
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
    metadataOutput.metadataObjectTypes = formats
    if let scanFrame = scanFrame {
      // 0.75 to adjust the frame from 1.777 aspect ratio (1280x720) to 1.333 (640x480)
      metadataOutput.rectOfInterest = CGRect(
        x: 0.5 - (scanFrame[1] * 0.75) / 2.0,
        y: 0.5 - scanFrame[0] / 2.0,
        width: scanFrame[1] * 0.75,
        height: scanFrame[0]
      )
    }
    
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

public class FlutterNativeBarcodeScannerPlugin: NSObject, FlutterPlugin {
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
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_native_barcode_scanner", binaryMessenger: registrar.messenger())
    let instance = FlutterNativeBarcodeScannerPlugin(registry: registrar.textures(), messenger: registrar.messenger(), methodChannel: channel)
    
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
      result(FlutterMethodNotImplemented)
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
    var formats: [AVMetadataObject.ObjectType] = [.qr, .ean8, .ean13, .code39, .code93, .code128, .dataMatrix, .pdf417, .itf14, .upce]
    var scanFrame: [Double]?
    
    // Check for arguments
    if let args = call.arguments as? [String: Any] {
      // Check for "formats" argument.
      if let fmts = args["formats"] as? [String] {
        formats = []
        
        for f in fmts {
          if let formatObjectType = FlutterNativeBarcodeScannerFormats[f] {
            formats.append(formatObjectType)
          }
        }
      }
      
      // Check for "scanFrame" argument.
      if let _scanFrame = args["scanFrame"] as? [Double], _scanFrame.count == 2 {
        scanFrame = _scanFrame
      }
    }
    
    self.cam.startScanning(formats: formats, scanFrame: scanFrame) { r in
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
