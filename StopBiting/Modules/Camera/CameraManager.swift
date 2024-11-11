import AVFoundation
import Vision
import SwiftUI
import AppKit

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    private var checkTimer: Timer?
    private var isProcessingFrame = false
    private var shouldProcessNextFrame = false

    @Published var session = AVCaptureSession()
    @Published var mouthDetected = false
    @Published var mouthRect: CGRect?
    @Published var handsFingersPositions: [[CGPoint]] = []
    @Published var handInMouth = false
    @Published var lastBitingImage: NSImage?
    private var currentBuffer: CVPixelBuffer?
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated)
    
    private var lastFaceDetectionTime: Date = .distantPast
    private let faceDetectionTimeout: TimeInterval = 10.0
    
    @Published var checkInterval: Double = 2.0 {
        didSet {
            setupTimer()
        }
    }
    
    private override init() {
        super.init()
        print("🎥 Initializing CameraManager...")
        checkPermissionAndSetupSession()
        setupTimer()
    }
    
    private func setupTimer() {
        checkTimer?.invalidate()
        checkTimer = Timer(timeInterval: max(0.1, checkInterval), target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(checkTimer!, forMode: .common)
    }
    
    @objc private func timerFired() {
        if !isProcessingFrame && session.isRunning {
            processNextFrame()
        } else {
            print("⏭️ Skipping timer - \(isProcessingFrame ? "still processing" : "session not running")")
        }
    }
    
    private func processNextFrame() {
        isProcessingFrame = true
        shouldProcessNextFrame = true
        print("\n⏱️ Processing frame at: \(Date().formatted(date: .omitted, time: .standard))")
        print("📊 Status: Mouth[\(mouthDetected ? "✅" : "❌")] Hands[\(handsFingersPositions.count)]")
    }
    
    func checkPermissionAndSetupSession() {
        print("🔍 Checking camera permissions...")
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                print("✅ Camera permission already granted")
                setupCaptureSession()
                
            case .notDetermined:
                print("⏳ Requesting camera permission...")
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    if granted {
                        print("✅ Camera permission granted")
                        DispatchQueue.main.async {
                            self?.setupCaptureSession()
                        }
                    } else {
                        print("❌ Camera permission denied")
                    }
                }
                
            case .denied:
                print("❌ Camera access denied. Please enable in System Settings")
                if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(settingsURL)
                }
                
            case .restricted:
                print("❌ Camera access restricted")
                
            @unknown default:
                print("❓ Unknown camera permission status")
        }
    }
    
    private func setupCaptureSession() {
        print("🎥 Setting up camera session...")
        
        if !session.inputs.isEmpty {
            print("🔄 Resetting existing camera session")
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            session.commitConfiguration()
        }
        
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("❌ Failed to get front camera device")
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                print("✅ Camera input configured")
            } else {
                print("❌ Cannot add video input")
                return
            }
        } catch {
            print("❌ Error creating video input: \(error)")
            return
        }
        
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            print("✅ Camera output configured")
        } else {
            print("❌ Cannot add video output")
            return
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            print("🎥 Starting camera session...")
            self?.session.startRunning()
            print("✅ Camera session started")
        }
    }
    
    func cleanup() {
        print("🧹 Cleaning up resources...")
        checkTimer?.invalidate()
        checkTimer = nil
        session.stopRunning()
        print(" Cleanup complete")
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        defer { isProcessingFrame = false }
        
        guard shouldProcessNextFrame else { return }
        shouldProcessNextFrame = false
        
        // If we haven't seen a face recently, process fewer frames
        let now = Date()
        if !mouthDetected && now.timeIntervalSince(lastFaceDetectionTime) < faceDetectionTimeout {
            if arc4random_uniform(4) != 0 {
                return
            }
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        currentBuffer = pixelBuffer
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        let faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleMouthDetection(request: request)
        }
        
        do {
            try requestHandler.perform([faceRequest])
            
            if self.mouthDetected {
                let handRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
                    self?.handleHandsWithFingersDetection(request: request)
                }
                handRequest.maximumHandCount = 1
                try requestHandler.perform([handRequest])
            }
        } catch {
            print("Vision request error: \(error)")
        }
    }
    
    private func handleMouthDetection(request: VNRequest) {
        guard let observations = request.results as? [VNFaceObservation] else {
            DispatchQueue.main.async {
                self.mouthDetected = false
                self.mouthRect = nil
            }
            return
        }

        if let _ = observations.first {
            lastFaceDetectionTime = Date()
        }
        
        print("👥 Found \(observations.count) faces")
        
        
        guard let faceObservation = observations.first else {
            DispatchQueue.main.async {
                self.mouthDetected = false
                self.mouthRect = nil
            }
            return
        }
    
        
        if let landmarks = faceObservation.landmarks {
            if let mouth = landmarks.outerLips {
                let mouthPoints = mouth.normalizedPoints.map {
                    CGPoint(x: $0.x * faceObservation.boundingBox.width + faceObservation.boundingBox.origin.x,
                           y: $0.y * faceObservation.boundingBox.height + faceObservation.boundingBox.origin.y)
                }
                
                let xCoords = mouthPoints.map { $0.x }
                let yCoords = mouthPoints.map { $0.y }
                
                if let minX = xCoords.min(),
                   let maxX = xCoords.max(),
                   let minY = yCoords.min(), 
                   let maxY = yCoords.max() {
                    let mouthBounds = CGRect(x: minX,
                                           y: minY,
                                           width: maxX - minX,
                                           height: maxY - minY)
                    
                    DispatchQueue.main.async {
                        self.mouthDetected = true
                        self.mouthRect = mouthBounds
                    }
                }
            }
        }
    }
    
    private func calculateAveragePoint(from points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let xSum = points.reduce(0, { $0 + $1.x })
        let ySum = points.reduce(0, { $0 + $1.y })
        return CGPoint(x: xSum / CGFloat(points.count), y: ySum / CGFloat(points.count))
    }
    
    
    private func handleHandsWithFingersDetection(request: VNRequest) {
        guard let results = request.results as? [VNHumanHandPoseObservation] else { return }
        var detectedHandsFingersPositions: [[CGPoint]] = []

        for observation in results {
            guard let points = try? observation.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.all) else { continue }
            
            let tipPoints = [
                VNHumanHandPoseObservation.JointName.thumbTip,
                VNHumanHandPoseObservation.JointName.indexTip,
                VNHumanHandPoseObservation.JointName.middleTip,
                VNHumanHandPoseObservation.JointName.ringTip,
                VNHumanHandPoseObservation.JointName.littleTip
            ]
            
            var handFingersPositions: [CGPoint] = []
            for tipPoint in tipPoints {
                if let point = points[tipPoint],
                   point.confidence > 0.3 {
                    handFingersPositions.append(point.location)
                }
            }

            if !handFingersPositions.isEmpty {
                detectedHandsFingersPositions.append(handFingersPositions)
            }
        }
        
        let handInMouth = self.mouthDetected && isHandNearFace(handsFingersPositions: detectedHandsFingersPositions)
        
        DispatchQueue.main.async {
            let wasHandInMouth = self.handInMouth
            self.handsFingersPositions = detectedHandsFingersPositions
            self.handInMouth = handInMouth
            
            if !wasHandInMouth && handInMouth {
                self.captureScreenshot()
            }
        }
    }

    private func isHandNearFace(handsFingersPositions: [[CGPoint]]) -> Bool {
        guard let mouthRect = self.mouthRect else { return false }
        
        
        for handFingersPositions in handsFingersPositions {
            for fingerPosition in handFingersPositions {
                if mouthRect.contains(fingerPosition) {
                    print("🚨 Finger detected near mouth!")
                    return true
                }
            }
        }

        return false
    }
    
    private func captureScreenshot() {
        guard let pixelBuffer = currentBuffer else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = 0.5
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let context = CIContext(options: [.useSoftwareRenderer: false]) // Use GPU when available
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }
        
        let screenshot = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        DispatchQueue.main.async {
            self.lastBitingImage = screenshot
        }
    }
}
