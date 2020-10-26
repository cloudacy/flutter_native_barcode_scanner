import Flutter
import UIKit
import AVFoundation
import CoreMotion
import libkern

// Format used for video and image streaming.
let videoFormat = FourCharCode(kCVPixelFormatType_32BGRA)

protocol FrameExtractorDelegate: class {
    func captured(image: UIImage)
}

@available(iOS 10.0, *)
public class QrCam: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, FlutterTexture {
  
  private let position = AVCaptureDevice.Position.back
  private let quality = AVCaptureSession.Preset.medium
  
  private var permissionGranted = false
  private let sessionQueue = DispatchQueue(label: "session queue")
  private let captureSession = AVCaptureSession()
  private let context = CIContext()
  
  private var pixelBuffer: CVPixelBuffer?
  
  weak var delegate: FrameExtractorDelegate?
  
  private(set) var previewSize = CGSize(width: 1920, height: 1080)
  var onFrameAvailable: (() -> Void)?
  var methodChannel: FlutterMethodChannel?
  
  private var feedbackGenerator = UINotificationFeedbackGenerator()
  
  public init(methodChannel: FlutterMethodChannel) {
    super.init()
    
    // request access
    AVCaptureDevice.requestAccess(for: .video) { (granted) in
      if (granted) {
        self.configureSession()
        self.captureSession.startRunning()
        self.methodChannel = methodChannel
      } else {
        // TODO: send error when no access to the camera was granted
      }
    }
  }
  
  private func configureSession() {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = quality
    let videoDevice = AVCaptureDevice.default(for: .video)
    guard
      let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
      captureSession.canAddInput(videoDeviceInput)
    else { return }
    captureSession.addInput(videoDeviceInput)
    
    let videoOutput = AVCaptureVideoDataOutput()
    let metadataOutput = AVCaptureMetadataOutput()
    
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: videoFormat)
    ]
    videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
    guard captureSession.canAddOutput(videoOutput) else { return }
    captureSession.addOutput(videoOutput)
    captureSession.addOutput(metadataOutput)
    
    
    // configure metadataOutput
    
    // support qr codes
    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue(label: "sample buffer"))
    metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .code39, .code93, .code128, .pdf417, .upce, .dataMatrix]
    captureSession.commitConfiguration()
  }

  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    
    if onFrameAvailable != nil {
      onFrameAvailable?()
    }
  }

  public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    captureSession.stopRunning()
    
    if let metadataObject = metadataObjects.first {
      guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
      guard let stringValue = readableObject.stringValue else { return }
      
      // we can only do this in main thread
      DispatchQueue.main.async {
        // haptic feedback (vibrate)
        self.feedbackGenerator.prepare()
        self.feedbackGenerator.notificationOccurred(.success)
      }
      
      print("qr code found: " + stringValue)
      methodChannel?.invokeMethod("barcode", arguments: stringValue)
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
  private var dispatchQueue: DispatchQueue?
  
  private(set) var registry: FlutterTextureRegistry
  private(set) var messenger: FlutterBinaryMessenger
  private(set) var methodChannel: FlutterMethodChannel
  
  private(set) var textureRegistry: FlutterTextureRegistry? = nil
  
  private(set) var flutterResult: FlutterResult? = nil
  private(set) var captureSession: AVCaptureSession? = nil

  init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger, methodChannel: FlutterMethodChannel) {
    self.registry = registry
    self.messenger = messenger
    self.methodChannel = methodChannel
  }
  
  public class func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_qr_scan", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterQrScanPlugin(registry: registrar.textures(), messenger: registrar.messenger(), methodChannel: channel)
    
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if dispatchQueue == nil {
      dispatchQueue = DispatchQueue(label: "io.cloudacy.flutter_qr_scan.dispatchQueue")
    }
    
    switch call.method {
    case "availableCameras":
      result(findAvailableCameras())
      break
    case "start":
      initializeQrScanner(call: call, result: result)
      break
    case "stop":
      captureSession?.stopRunning()
      break
    default:
      result(FlutterError(code: "InvalidMethod", message: "Invalid method \(call.method)!", details: nil))
      break
    }
  }

  public func initializeQrScanner(call: FlutterMethodCall, result: FlutterResult) -> Void {
    let cam = QrCam(methodChannel: methodChannel)
    
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

  public func findAvailableCameras() -> [[String: String]] {
    let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    let devices = discoverySession.devices
    var reply: [[String : String]] = []
    
    for device in devices {
      var lensFacing = ""
      switch device.position {
      case .back:
        lensFacing = "back"
      case .front:
        lensFacing = "front"
      case .unspecified:
        lensFacing = "external"
      @unknown default:
        continue
      }
      reply.append(["id": device.uniqueID, "lensFacing": lensFacing])
    }
    
    return reply
  }

  public func findCameraDevice() -> AVCaptureDevice? {
    return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
  }
}


@available(iOS 10.0, *)
extension SwiftFlutterQrScanPlugin: AVCaptureMetadataOutputObjectsDelegate {
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

private func getFlutterError(error: Error?) -> FlutterError? {
    return FlutterError(code: "Error", message: (error as NSError?)?.domain, details: error?.localizedDescription)
}
