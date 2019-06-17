import Flutter
import UIKit
import AVFoundation

public class QrCam: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, FlutterStreamHandler, AVCaptureMetadataOutputObjectsDelegate {
    var onFrameAvailable: (() -> Void)?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    private(set) var latestPixelBuffer: CVPixelBuffer?
    private(set) var captureSession: AVCaptureSession?
    private(set) var captureDevice: AVCaptureDevice?
    private(set) var captureVideoOutput: AVCaptureVideoDataOutput?
    private(set) var previewSize = CGSize.zero
    private(set) var captureSize = CGSize.zero
    var isScanning = false
    var channel: FlutterMethodChannel?
    
    
    //  Converted to Swift 4 by Swiftify v4.2.37326 - https://objectivec2swift.com/
    init(cameraName: String?, resolutionPreset: String?, dispatchQueue: DispatchQueue) throws {
        super.init()
        captureSession = AVCaptureSession()
        
        captureDevice = AVCaptureDevice(uniqueID: cameraName!)
        
        let dimensions: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(captureDevice!.activeFormat.formatDescription)
        previewSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height));
    }
    
    public func start() {
        captureSession?.startRunning()
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject
        //        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
        if isScanning {
            performSelector(onMainThread: #selector(self.stopScanning(withResult:)), with: metadataObj?.stringValue, waitUntilDone: false)
        }
        //        }
    }
    
    @objc public func stopScanning(withResult result: String?) {
        if !(result?.isEqual("") ?? false) && isScanning {
            channel?.invokeMethod("updateCode", arguments: result)
            isScanning = false
        }
    }

    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = latestPixelBuffer else { return nil }
        //        while !OSAtomicCompareAndSwapPtrBarrier(pixelBuffer, nil, &latestPixelBuffer) {
        //            pixelBuffer = latestPixelBuffer
        //        }
        
        // see this: https://stackoverflow.com/questions/51543606/how-to-copy-a-cvpixelbuffer-in-swift?rq=1
        return Unmanaged.passRetained(pixelBuffer)
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    public func close() {
        captureSession?.stopRunning()
        for input in captureSession?.inputs ?? [] {
            captureSession?.removeInput(input)
        }
        for output in captureSession?.outputs ?? [] {
            captureSession?.removeOutput(output)
        }
    }
    
    public func startScanning() {
        // Added this delay to avoid encountering race condition
        let delayInSeconds: Double = 0.1
        let popTime = DispatchTime.now() + Double(Int64(delayInSeconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: popTime, execute: {
            self.isScanning = true
        })
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Capture Output!")
        if output == captureVideoOutput {
            let newBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            latestPixelBuffer = newBuffer
            if (onFrameAvailable != nil) {
                onFrameAvailable!()
            }
        }
        if !CMSampleBufferDataIsReady(sampleBuffer) {
            eventSink!([
                "event": "error",
                "errorDescription": "sample buffer is not ready. Skipping sample"
                ])
            return
        }
    }
}

public class SwiftQrScanPlugin: NSObject, FlutterPlugin {
    private var dispatchQueue: DispatchQueue?

    private(set) var registry: FlutterTextureRegistry
    private(set) var messenger: FlutterBinaryMessenger
    private(set) var methodChannel: FlutterMethodChannel
    
    private(set) var textureRegistry: FlutterTextureRegistry? = nil
    
    private(set) var flutterResult: FlutterResult? = nil
    private(set) var captureSession: AVCaptureSession? = nil
    
    private var camera: QrCam?
    
    init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger, methodChannel: FlutterMethodChannel) {
        self.registry = registry
        self.messenger = messenger
        self.methodChannel = methodChannel
    }
    
    public class func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "io.cloudacy.qr_scan", binaryMessenger: registrar.messenger())
        let instance = SwiftQrScanPlugin(registry: registrar.textures(), messenger: registrar.messenger(), methodChannel: channel)
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        if dispatchQueue == nil {
            dispatchQueue = DispatchQueue(label: "io.cloudacy.qr_scan.dispathQueue")
        }
        
        // Invoke the plugin on another dispatch queue to avoid blocking the UI.
        dispatchQueue?.async(execute: {
            self.handleMethodCallAsync(call, result: result)
        })
    }
    
    func handleMethodCallAsync(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "availableCameras":
            result(findAvailableCameras())
            break
        case "initialize":
            result(initializeQrScanner(call: call))
            break
        case "init":
            reset()
            result(nil)
            break
        case "startScanning":
            camera!.startScanning()
            break
        default:
            result(FlutterError(code: "InvalidMethod", message: "Invalid method \(call.method)!", details: nil))
            break
        }
    }
    
    public func reset() {
        if (camera != nil) {
            camera?.close()
        }
    }
    
    public func initializeQrScanner(call: FlutterMethodCall) -> [String: Any] {
        let cameraName = (call.arguments as AnyObject)["cameraName"] as! String
        let resolutionPreset = (call.arguments as AnyObject)["resolutionPreset"] as! String
        _ = (call.arguments as AnyObject)["codeFormats"] as! [Any]
        var error: Error?
        var cam: QrCam? = nil
        
        do {
            if let dispatchQueue = dispatchQueue {
                cam = try QrCam(cameraName: cameraName, resolutionPreset: resolutionPreset, dispatchQueue: dispatchQueue)
            }
        } catch {
        }
        
        if error != nil {
            return ["Error": getFlutterError(error: error)]
        }
        
        if (camera != nil) {
            camera?.close()
        }
        
        let textureId = registry.register(cam!)
        camera = cam
        
        cam?.onFrameAvailable = {
            self.registry.textureFrameAvailable(textureId)
        }
        
        let eventChannel = FlutterEventChannel(name: String(format: "io.cloudacy.qr_scan/cameraEvents%lld", textureId ), binaryMessenger: messenger)
        
        eventChannel.setStreamHandler(cam)
        cam?.eventChannel = eventChannel

        return [
            "textureId": NSNumber(value: textureId),
            "previewWidth": cam?.previewSize.width ?? 0.0,
            "previewHeight": cam?.previewSize.height ?? 0.0,
            "captureWidth": cam?.captureSize.width ?? 0.0,
            "captureHeight": cam?.captureSize.height ?? 0.0
        ]
        
        cam?.start()
    }
    
    public func findAvailableCameras() -> [[String: String]] {
        if #available(iOS 10.0, *) {
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
                }
                reply.append(["name": device.uniqueID, "lensFacing": lensFacing])
            }
            
            return reply
        } else {
            // Fallback on earlier versions
            return []
        }
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

private func getFlutterError(error: Error?) -> FlutterError? {
    return FlutterError(code: "Error", message: (error as NSError?)?.domain, details: error?.localizedDescription)
}
