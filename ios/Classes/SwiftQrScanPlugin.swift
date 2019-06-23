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

public class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, FlutterTexture, FlutterStreamHandler {
    private let position = AVCaptureDevice.Position.back
    private let quality = AVCaptureSession.Preset.medium
    
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    
    private var pixelBuffer: CVPixelBuffer?
    
    weak var delegate: FrameExtractorDelegate?
    
    private(set) var previewSize = CGSize(width: 1920, height: 1080)
    var onFrameAvailable: ((_ pixelBuffer: CVPixelBuffer?) -> Void)?
    
    override public init() {
        super.init()
        checkPermission()

        self.configureSession()
        self.captureSession.startRunning()
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
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: FourCharCode(kCVPixelFormatType_32BGRA))
        ]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        // latestPixelBuffer = pixelBuffer
        print("Capture Output!")
        
        if pixelBuffer != nil {
            var image = CIImage(cvPixelBuffer: pixelBuffer!)
            print(image)
        }
        
        if onFrameAvailable != nil {
            onFrameAvailable?(pixelBuffer)
        }
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if self.pixelBuffer == nil {
            return nil
        }
        print("copy")
        
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

@available(iOS 10.0, *)
public class QrCam: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, FlutterStreamHandler {
    
    private var dispatchQueue: DispatchQueue?

    var onFrameAvailable: (() -> Void)?
    var enableAudio = false
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    private(set) var latestPixelBuffer: CVPixelBuffer?
    private(set) var captureDevice: AVCaptureDevice?
    private(set) var capturePhotoOutput: AVCapturePhotoOutput?
    private(set) var captureVideoOutput: AVCaptureVideoDataOutput?
    private(set) var captureVideoInput: AVCaptureInput?
    private(set) var previewSize = CGSize.zero
    private(set) var captureSize = CGSize.zero
    var isScanning = false
    var channel: FlutterMethodChannel?

    var videoOutput: AVCaptureVideoDataOutput?
    var motionManager: CMMotionManager?
    

    private let position = AVCaptureDevice.Position.front
    private let quality = AVCaptureSession.Preset.medium
    
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    
    weak var delegate: FrameExtractorDelegate?
    
    
    init(cameraName: String?, resolutionPreset: String?, enableAudio: Bool) {
        super.init()
//        checkPermission()
//
//        sessionQueue.async { [unowned self] in
//            self.configureSession()
//            self.captureSession.startRunning()
//        }
        
//        self.enableAudio = enableAudio
//        self.dispatchQueue = dispatchQueue
//        captureSession = AVCaptureSession()
//
//        captureDevice = AVCaptureDevice(uniqueID: cameraName!)
//
//        captureVideoOutput = AVCaptureVideoDataOutput()
//        captureVideoOutput?.videoSettings = [
//            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: videoFormat)
//        ]
//        captureVideoOutput?.alwaysDiscardsLateVideoFrames = true
//        captureVideoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue.main)
//
//        var connection: AVCaptureConnection? = nil
//        if let ports = captureVideoInput?.ports, let captureVideoOutput = captureVideoOutput {
//            connection = AVCaptureConnection(inputPorts: ports, output: captureVideoOutput)
//        }
//
//        if captureDevice?.position == .front {
//            connection?.isVideoMirrored = true
//        }
//
//        connection?.videoOrientation = .portrait
//
//        if let captureVideoInput = captureVideoInput {
//            captureSession?.addInputWithNoConnections(captureVideoInput)
//        }
//
//        if let captureVideoOutput = captureVideoOutput {
//            captureSession?.addOutputWithNoConnections(captureVideoOutput)
//        }
//
//        if let connection = connection {
//            captureSession?.add(connection)
//        }
//
//
//        capturePhotoOutput = AVCapturePhotoOutput()
//
//        capturePhotoOutput?.isHighResolutionCaptureEnabled = true
//        if let capturePhotoOutput = capturePhotoOutput {
//            captureSession?.addOutput(capturePhotoOutput)
//        }
//
//        motionManager = CMMotionManager()
//        motionManager?.startAccelerometerUpdates()
//
//        setCaptureSessionPreset(resolutionPreset)
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
    
    private func configureSession() {
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice() else { return }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: FourCharCode(kCVPixelFormatType_32BGRA))
        ]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
    }
    
    private func selectCaptureDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.devices().filter {
            ($0 as AnyObject).hasMediaType(AVMediaType.video) &&
                ($0 as AnyObject).position == position
            }.first
    }
    
//    public func start() {
//        captureSession?.startRunning()
//    }
    
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

    
//    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
//        print("Copy pixel buffer")
//        guard let pixelBuffer = latestPixelBuffer else { return nil }
//        //        while !OSAtomicCompareAndSwapPtrBarrier(pixelBuffer, nil, &latestPixelBuffer) {
//        //            pixelBuffer = latestPixelBuffer
//        //        }
//
//        // see this: https://stackoverflow.com/questions/51543606/how-to-copy-a-cvpixelbuffer-in-swift?rq=1
//        return Unmanaged.passRetained(pixelBuffer).autorelease()
//    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
//    public func close() {
//        captureSession?.stopRunning()
//        for input in captureSession?.inputs ?? [] {
//            captureSession?.removeInput(input)
//        }
//        for output in captureSession?.outputs ?? [] {
//            captureSession?.removeOutput(output)
//        }
//    }
    
    public func startScanning() {
        // Added this delay to avoid encountering race condition
        let delayInSeconds: Double = 0.1
        let popTime = DispatchTime.now() + Double(Int64(delayInSeconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: popTime, execute: {
            self.isScanning = true
        })
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        print("copy")
        guard let pixelBuffer = latestPixelBuffer else { return nil }
        
        return Unmanaged.passRetained(pixelBuffer)
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        latestPixelBuffer = imageBuffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    private func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        latestPixelBuffer = pixelBuffer
        print("Capture Output!")
        
//        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
//
//        DispatchQueue.main.async { [unowned self] in
//            self.delegate?.captured(image: uiImage)
//        }
        
//        if output == captureVideoOutput {
//            let newBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
//            latestPixelBuffer = newBuffer
//            if (onFrameAvailable != nil) {
//                onFrameAvailable!()
//            }
//        }
//        if !CMSampleBufferDataIsReady(sampleBuffer) {
//            eventSink!([
//                "event": "error",
//                "errorDescription": "sample buffer is not ready. Skipping sample"
//                ])
//            return
//        }
    }
}

@available(iOS 10.0, *)
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
        let cameraName = (call.arguments as AnyObject)["cameraName"] as! String
        let resolutionPreset = (call.arguments as AnyObject)["resolutionPreset"] as! String
        let enableAudio = (call.arguments as AnyObject)["enableAudio"] as AnyObject
//        let error: Error?
        
        
        let extractor = FrameExtractor()
//        let cam: QrCam? = QrCam(cameraName: cameraName, resolutionPreset: resolutionPreset, enableAudio: enableAudio.boolValue)
        
//        do {
//            if let dispatchQueue = dispatchQueue {
//                cam = try QrCam(cameraName: cameraName, resolutionPreset: resolutionPreset, enableAudio: enableAudio.boolValue ?? false, dispatchQueue: dispatchQueue)
//            }
//        } catch {
//        }
        
//        if error != nil {
//            result(["Error": getFlutterError(error: error)])
//        }
        
//        if (camera != nil) {
//            camera?.close()
//        }
        
        let textureId = registry.register(extractor)
        
        func frameAvailable(pixelBuffer: CVPixelBuffer?) {
            var image = CIImage(cvPixelBuffer: pixelBuffer!)
            self.registry.textureFrameAvailable(textureId)
        }
        
        extractor.onFrameAvailable = frameAvailable
        
////        camera = cam
//
//        cam?.onFrameAvailable = {
//            self.registry.textureFrameAvailable(textureId)
//        }
//
        let eventChannel = FlutterEventChannel(name: String(format: "io.cloudacy.qr_scan/cameraEvents%lld", textureId ), binaryMessenger: messenger)
//
        eventChannel.setStreamHandler(extractor)
//        cam?.eventChannel = eventChannel
//
//        let previewWidth = cam?.previewSize.width
//        let previewHeight = cam?.previewSize.height
//        let captureWidth = cam?.captureSize.width
//        let captureHeight = cam?.captureSize.height

//        let resultObject = [
////            "textureId": textureId,
////            "previewWidth": previewWidth,
////            "previewHeight": previewHeight,
////            "captureWidth": captureWidth,
////            "captureHeight": captureHeight
//            ] as [String : Any]
        
        let resultObject = [
            "textureId": textureId,
            "previewWidth": extractor.previewSize.width,
            "previewHeight": extractor.previewSize.height
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

@available(iOS 10.0, *)
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
