import Flutter
import UIKit

public class SwiftQrScanPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "io.cloudacy.qr_scan", binaryMessenger: registrar.messenger())
    let instance = SwiftQrScanPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    //result("iOS " + UIDevice.current.systemVersion)
    let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)
    let image = CIImage(contentsOf: URL(string: "https://support.apple.com/library/content/dam/edam/applecare/images/de_DE/iOS/ios12-iphone-x-camera-open-safari-qr-code.jpg")!)
    let features = detector?.features(in: image!)
    features?.forEach({(feature) -> Void in
        if let qrFeature = feature as? CIQRCodeFeature {
                result(qrFeature.messageString)
            }
        }
    )
    //result("count: \(features?.count)")
  }
}
