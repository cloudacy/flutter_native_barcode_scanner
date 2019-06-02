import Flutter
import UIKit
import AVFoundation

public class SwiftQrScanPlugin: NSObject, FlutterPlugin {
  var flutterResult: FlutterResult? = nil
  var captureSession: AVCaptureSession? = nil
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "io.cloudacy.qr_scan", binaryMessenger: registrar.messenger())
    let instance = SwiftQrScanPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    self.flutterResult = result
    
    //result("iOS " + UIDevice.current.systemVersion)
    // QR code test
    /*
    let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)
    let image = CIImage(contentsOf: URL(string: "https://support.apple.com/library/content/dam/edam/applecare/images/de_DE/iOS/ios12-iphone-x-camera-open-safari-qr-code.jpg")!)
    let features = detector?.features(in: image!)
    features?.forEach(
      {(feature) -> Void in
        if let qrFeature = feature as? CIQRCodeFeature {
          result(qrFeature.messageString)
        }
      }
    )
    //result("count: \(features?.count)")
    
    */
    // Camera test
    self.captureSession = AVCaptureSession()
    // Begin/Commit configuration allows atomic configuration changes
    guard let captureSession = self.captureSession else {
      result(FlutterError(code: "NoCaptureSession", message: "Unable to create a capture session!", details: nil))
      return
    }
    captureSession.beginConfiguration()
    
    // Try to find a camera device.
    guard let cameraDevice = findCameraDevice() else {
      result(FlutterError(code: "NoCameraFound", message: "No camera device found!", details: nil))
      return
    }
    cameraDevice.activeVideoMinFrameDuration = CMTime(seconds: 1.0, preferredTimescale: 1)
    
    // Try to set the found camera device as an input.
    guard let cameraDeviceInput = try? AVCaptureDeviceInput(device: cameraDevice), captureSession.canAddInput(cameraDeviceInput) else {
      result(FlutterError(code: "NoCameraInput", message: "Unable to use the camera device as an input!", details: nil))
      return
    }
    
    // Add the input to the captureSession.
    captureSession.addInput(cameraDeviceInput)
    
    // Create an output.
    // https://medium.com/@abhimuralidharan/how-to-create-a-simple-qrcode-barcode-scanner-app-in-ios-swift-fd9970a70859
    let metadataOutput = AVCaptureMetadataOutput()
    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    metadataOutput.metadataObjectTypes = [.qr]
    
    captureSession.commitConfiguration()
    
    // Start scanning for a QR code.
    captureSession.startRunning()
  }

  public func findCameraDevice() -> AVCaptureDevice? {
    let cameraDevice : AVCaptureDevice?
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
      guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
      guard let stringValue = readableObject.stringValue else { return }
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
