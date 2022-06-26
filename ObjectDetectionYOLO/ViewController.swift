//
//  ViewController.swift
//  ObjectDetectionYOLO
//
//  Created by Andi Xu on 12/22/21.
//

import UIKit
import Vision
import CoreMedia
import AVFoundation

class ViewController: UIViewController, VideoCaptureDelegate {
    
    
    
    @IBOutlet weak var videoPreview: UIView!
    
    @IBOutlet weak var boxesView: DrawingBoundingBoxView!
    
    let objectDectectionModel = YOLOv3()
    
    var object_detect_request: VNCoreMLRequest?
    var ocr_request: VNRecognizeTextRequest!
    
    var visionModel: VNCoreMLModel?
    var textModel: VNCoreMLModel?
    
    var isInferencing = false
    var videoCapture: VideoCapture!
//    let semaphore = DispatchSemaphore(value: 1)
    var lastExecution = Date()
    
    var predictions: [VNRecognizedObjectObservation] = []
    var requiredItem: Set<String> = []
    
    var currentPixelBuffer: CVPixelBuffer?
    var regionOfInterest = CGRect(x: 0,y: 0,width: 0,height: 0)
    
    let numberTracker = StringTracker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.boxesView.requiredItem = self.requiredItem

        setUpRequest()
        setUpCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    
    func setUpRequest() {
        if let visionModel = try? VNCoreMLModel(for: objectDectectionModel.model) {
            self.visionModel = visionModel
            object_detect_request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            object_detect_request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("fail to create vision model")
        }
        ocr_request = VNRecognizeTextRequest(completionHandler: recognizeTextFinish)
    }
    
    
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
        
    }
    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    


}


extension ViewController {
    
    
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
//        currentPixelBuffer = pixelBuffer
        guard let request = object_detect_request else { fatalError() }
//        self.semaphore.wait()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    

    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let predictions = request.results as? [VNRecognizedObjectObservation] {
            self.predictions = predictions
            DispatchQueue.main.async {
                self.boxesView.predictedObjects = predictions
                self.isInferencing = false
            }
            if predictions.count > 0 && predictions[0].label == "bus" {
                regionOfInterest = predictions[0].boundingBox
            } else {
                regionOfInterest = CGRect(x: 0,y: 0,width: 0,height: 0)
            }
      
        } else {
            self.isInferencing = false
        }

    }
    
    func startTextRecognition(pixelBuffer: CVPixelBuffer){
        //if prediction.label != "bus" {return}
        let text_requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        let text_request = VNRecognizeTextRequest(completionHandler: recognizeTextFinish)
        text_request.regionOfInterest = regionOfInterest

        do {
            try text_requestHandler.perform([text_request])
        } catch {
            print("Unable to perform the request to recognize text: \(error).")
        }
    }
    
    func recognizeTextFinish(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return
        }
      
        let recognizedStrings = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance.
            return observation.topCandidates(1).first?.string
        }
        
        // Log any found strins.
        numberTracker.logFrame(strings: recognizedStrings)

        // Check if we have any temporally stable numbers.
        if let sureNumber = numberTracker.getStableString() {
            print("see stable   ",sureNumber)
            playSound(str: sureNumber)
            numberTracker.reset(string: sureNumber)
        }
//
    }
    
    
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        if !self.isInferencing, let pixelBuffer = pixelBuffer {
            self.isInferencing = true
            
            self.predictUsingVision(pixelBuffer: pixelBuffer)
            self.startTextRecognition(pixelBuffer: pixelBuffer)
        }
    }
    func playSound( str: String ){
        let utterance = AVSpeechUtterance(string: str)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
    
}
