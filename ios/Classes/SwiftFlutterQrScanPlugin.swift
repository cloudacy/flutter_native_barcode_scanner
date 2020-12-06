import Flutter
import UIKit
import AVFoundation
import CoreMotion
import libkern

public enum CaptureDeviceError : Error {
  case access
}

@available(iOS 10.0, *)
public class QrCam:
  NSObject,
  AVCaptureVideoDataOutputSampleBufferDelegate,
  AVCaptureMetadataOutputObjectsDelegate,
  FlutterTexture
{
  public  let captureSession = AVCaptureSession()
  
  private let quality = AVCaptureSession.Preset.medium
  private var pixelBuffer: CVPixelBuffer?
  
  public  var orientationObserver: NSObjectProtocol?
  public  var previewSize = CGSize(width: 1920, height: 1080)
  public  var onFrameAvailable: (() -> Void)?
  public  var methodChannel: FlutterMethodChannel?
  
  private let videoOutput = AVCaptureVideoDataOutput()
  private let metadataOutput = AVCaptureMetadataOutput()
  private let feedbackGenerator = UINotificationFeedbackGenerator()
  
  private let queue = DispatchQueue(label: "io.cloudacy.flutter_qr_scan")
  
  public init(methodChannel: FlutterMethodChannel) {
    self.methodChannel = methodChannel

    super.init()
    
    videoOutput.setSampleBufferDelegate(self, queue: queue)
  }
  
  public func startScanning(
    completion: @escaping (Result<Bool, CaptureDeviceError>) -> Void
  ) {
    // request access
    AVCaptureDevice.requestAccess(for: .video) { (granted) in
      if (granted) {
        self.configureSession()
        self.captureSession.startRunning()
        completion(.success(true))
      } else {
        completion(.failure(.access))
      }
    }
  }
  
  private func changeVideoOutputOrientation() {
    if let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) {
      switch UIDevice.current.orientation {
      case .portrait:
        connection.videoOrientation = .portrait
        break
      case .portraitUpsideDown:
        connection.videoOrientation = .portraitUpsideDown
        break
      // TODO: Find out why this has to be flipped.
      case .landscapeLeft:
        connection.videoOrientation = .landscapeRight
        break
      // TODO: Find out why this has to be flipped.
      case .landscapeRight:
        connection.videoOrientation = .landscapeLeft
        break
      default:
        // Do nothing.
        break
      }
    }
  }
  
  private func configureSession() {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = quality
    
    guard let videoDevice = AVCaptureDevice.default(for: .video) else {
      captureSession.commitConfiguration()
      return
    }
    
    guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
      captureSession.commitConfiguration()
      return
    }
    
    if captureSession.canAddInput(videoDeviceInput) {
      captureSession.addInput(videoDeviceInput)
    }
    
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
      
      orientationObserver = NotificationCenter.default.addObserver(
        forName: UIDevice.orientationDidChangeNotification,
        object: nil, queue: nil
      ) { _ in
        self.changeVideoOutputOrientation()
      }
      
      changeVideoOutputOrientation()
    }
    
    if captureSession.canAddOutput(metadataOutput) {
      captureSession.addOutput(metadataOutput)
    }
    
    // support qr codes
    metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
    metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .code39, .code93, .code128, .pdf417, .upce, .dataMatrix]
    
    captureSession.commitConfiguration()
    
    let dims = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
    previewSize = CGSize(width: CGFloat(dims.width), height: CGFloat(dims.height))
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

@available(iOS 10.0, *)
public class SwiftFlutterQrScanPlugin: NSObject, FlutterPlugin {
  private let registry: FlutterTextureRegistry
  private let messenger: FlutterBinaryMessenger
  private let methodChannel: FlutterMethodChannel
  
  private let cam: QrCam

  init(
    registry: FlutterTextureRegistry,
    messenger: FlutterBinaryMessenger,
    methodChannel: FlutterMethodChannel
  ) {
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
      // Remove the orientation observer.
      if let observer = cam.orientationObserver {
        NotificationCenter.default.removeObserver(observer, name: UIDevice.orientationDidChangeNotification, object: nil)
      }
      
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
    
    // TODO: Find out why previewWidth and previewHeight have to be flipped.
    return [
      "textureId": textureId,
      "previewWidth": self.cam.previewSize.height,
      "previewHeight": self.cam.previewSize.width
    ]
  }
    
  public func initializeQrScanner(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
    self.cam.startScanning() { r in
      switch r {
      case .failure(let error):
        switch error {
        case .access:
          result(FlutterError(code: "CaptureDeviceAccess", message: "The user didn't allow access to the capture device!", details: nil))
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
