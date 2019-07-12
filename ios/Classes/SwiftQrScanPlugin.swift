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

public class QrCam: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, FlutterTexture, FlutterStreamHandler {
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
    var eventChannel: FlutterEventChannel?
    var methodChannel: FlutterMethodChannel?

    private var feedbackGenerator: Any?

    public init(methodChannel: FlutterMethodChannel) {
        super.init()
        checkPermission()

        self.configureSession()
        self.captureSession.startRunning()

        self.methodChannel = methodChannel

        if #available(iOS 10.0, *) {
            feedbackGenerator = UINotificationFeedbackGenerator()
        }
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }

    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }

    private func selectCaptureDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.devices().filter {
            ($0 as AnyObject).hasMediaType(AVMediaType.video) &&
                ($0 as AnyObject).position == position
            }.first
    }

    private func configureSession() {
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice() else { return }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)

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

        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
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
                if #available(iOS 10.0, *) {
                    let generator = self.feedbackGenerator as! UINotificationFeedbackGenerator
                    generator.prepare()
                    generator.notificationOccurred(.success)
                } else {
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                }
            }

            print("qr code found: " + stringValue)
            methodChannel?.invokeMethod("code", arguments: stringValue)
        }
    }

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if self.pixelBuffer == nil {
            return nil
        }

        return Unmanaged.passRetained(self.pixelBuffer!)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("listen")
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("cancel")
        return nil
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
            initializeQrScanner(call: call, result: result)
            break
//        case "init":
//            reset()
//            result(nil)
//            break
//        case "startScanning":
//            camera!.startScanning()
//            break
        default:
            result(FlutterError(code: "InvalidMethod", message: "Invalid method \(call.method)!", details: nil))
            break
        }
    }

//    public func reset() {
//        if (camera != nil) {
//            camera?.close()
//        }
//    }

    public func initializeQrScanner(call: FlutterMethodCall, result: FlutterResult) -> Void {
//        let cameraName = (call.arguments as AnyObject)["cameraName"] as! String
//        let resolutionPreset = (call.arguments as AnyObject)["resolutionPreset"] as! String
//        let enableAudio = (call.arguments as AnyObject)["enableAudio"] as AnyObject


        let cam = QrCam(methodChannel: methodChannel)

        let textureId = registry.register(cam)

        cam.onFrameAvailable = {
            self.registry.textureFrameAvailable(textureId)
        }

        let eventChannel = FlutterEventChannel(name: String(format: "io.cloudacy.qr_scan/cameraEvents%lld", textureId ), binaryMessenger: messenger)

        eventChannel.setStreamHandler(cam)
        cam.eventChannel = eventChannel

        let resultObject = [
            "textureId": textureId,
            "previewWidth": cam.previewSize.width,
            "previewHeight": cam.previewSize.height
            ] as [String : Any]

        result(resultObject)

//        cam?.start()
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
                reply.append(["id": device.uniqueID, "lensFacing": lensFacing])
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
