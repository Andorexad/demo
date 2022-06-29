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
import SwiftUI

class ViewController: UIViewController, VideoCaptureDelegate, UITextViewDelegate {
    
    
    
  
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var boxesView: DrawingBoundingBoxView!
    
    var textDisplayed: Set<String>=[]
    let objectDectectionModel = YOLOv3()
    
    var lastSpeakFrame = Int64(0)
    var lastSpeakSTring = ""
//    var isSpeaking = false
    
    var object_detect_request: VNCoreMLRequest?
    var ocr_request: VNRecognizeTextRequest!
    
    var visionModel: VNCoreMLModel?
    
    
    var isInferencing = false
    
    var videoCapture: VideoCapture!

    var lastExecution = Date()
    
    var predictions: [VNRecognizedObjectObservation] = []
    var requiredItem: Set<String> = []
    
    
    var regionOfInterest = CGRect(x: 0,y: 0,width: 0,height: 0)
    let numberTracker = StringTracker()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.boxesView.requiredItem = self.requiredItem

        setUpLabel()
        setUpToggle()
        
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
        self.videoPreview.bringSubviewToFront(boxesView)
        
    }
    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
//        videoCapture.previewLayer?.frame = videoPreview.bounds
        let bounds=videoPreview.bounds
        videoCapture.previewLayer?.frame = CGRect(x: bounds.minX, y: bounds.minY+40, width: bounds.width, height: bounds.height)
    }
    

    
    // MARK: Object detection
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = object_detect_request else { fatalError() }
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
                regionOfInterest = getROI(boundingBox: predictions[0].boundingBox)
            } else {
                regionOfInterest = CGRect(x: 0,y: 0,width: 0,height: 0)
            }
      
        } else {
            self.isInferencing = false
        }

    }
    
    // MARK: Text detection
    func startTextRecognition(pixelBuffer: CVPixelBuffer){
        let text_requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        let text_request = VNRecognizeTextRequest(completionHandler: recognizeTextFinish)
        text_request.regionOfInterest = regionOfInterest
        text_request.recognitionLevel = .accurate
        do {
            try text_requestHandler.perform([text_request])
        } catch {
            print("Unable to perform the request to recognize text: \(error).")
        }
    }
    
    func recognizeTextFinish(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedTextObservation] else { return }
        
        numberTracker.logFrame(results: results)
        
        if let sureNumber = numberTracker.getStableString() {
            
            if numberOnly.isOn {
                if sureNumber.first!.isNumber {
                    speakAndReset(sureNumber: sureNumber)
                }
                return
            }

            if (sureNumber == lastSpeakSTring && lastSpeakFrame < numberTracker.bestStringFrame-(30*5)) || (sureNumber != lastSpeakSTring && lastSpeakFrame < numberTracker.bestStringFrame-(30*3))  || lastSpeakFrame==0 {
                speakAndReset(sureNumber: sureNumber)
            }
            
        }

    }
    
    func speakAndReset(sureNumber: String){
//        print("say something: ", lastSpeakSTring, sureNumber,lastSpeakFrame)
        playSound(str: sureNumber)
        lastSpeakSTring=sureNumber
        lastSpeakFrame=numberTracker.bestStringFrame
        numberTracker.reset(string: sureNumber)
    
        // show in Label
        textDisplayed.insert(sureNumber)
        var string=""
        for str in self.textDisplayed {
//            print(str+"inserted")
            string=string+"\n"+str
        }
        print(string)
        DispatchQueue.main.async{
            self.label.text=string
//            self.label.setNeedsDisplay()
        }
        
        
    }
    
    // MARK: Helper functions
    
    func getROI(boundingBox: CGRect) -> CGRect{
        let x = max(boundingBox.minX, 0)
        let y = max(boundingBox.minY, 0)
        let width = min(boundingBox.width, (1 - x))
        let height = min(boundingBox.height, (1 - y))
        return CGRect(x: x,y: y,width: width,height: height)
    }
    
    func playSound( str: String ){
        let utterance = AVSpeechUtterance(string: str)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        let synthesizer = AVSpeechSynthesizer()
//        isSpeaking=true
        synthesizer.speak(utterance)
//        isSpeaking=false
    }
    
    
    
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        if !self.isInferencing, let pixelBuffer = pixelBuffer {
            self.isInferencing = true
            self.predictUsingVision(pixelBuffer: pixelBuffer)
            self.startTextRecognition(pixelBuffer: pixelBuffer)
        }
    }
    
    
    
    @IBOutlet weak var label: UILabel!
    func setUpLabel(){
//        label.frame=CGRect(x:0,y:videoPreview.bounds.maxY-60,width:videoPreview.bounds.width,height: videoPreview.bounds.height)
        label.text = "No text detected. \n  hihi"
        label.font = UIFont.preferredFont(forTextStyle: .body)
//        label.adjustsFontSizeToFitWidth
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .black
        label.backgroundColor = .yellow
//        label.
//        self.videoPreview.addSubview(label)
        self.videoPreview.bringSubviewToFront(label)
    }
    
    
//    let numberOnly = UISwitch(frame: CGRect(x:60,y:0,width: 30,height: 30))
    @IBAction func numberOnlyToggled(_ sender: Any) {
        if numberOnly.isOn{
            let tempset=self.textDisplayed
            for str in tempset {
                if (!str.first!.isNumber ){
                    self.textDisplayed.remove(str)
                }
            }
        }
    }
    @IBOutlet weak var numberOnly: UISwitch!
    func setUpToggle(){

        numberOnly.isUserInteractionEnabled=true
        numberOnly.isOn=false
        
//        self.videoPreview.addSubview(numberOnly)
    }
    
    
    
    
    
    
    
}
