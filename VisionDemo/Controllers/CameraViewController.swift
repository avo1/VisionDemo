//
//  CameraViewController.swift
//  VisionDemo
//
//  Created by dave on 11/12/17.
//  Copyright © 2017 dave. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

class CameraViewController: UIViewController {

    @IBOutlet weak var capturedImageView: RoundedShadowImageView!
    @IBOutlet weak var itemLabel: UILabel!
    @IBOutlet weak var confidenceLabel: UILabel!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var roundedLabelView: RoundedShadowView!
    @IBOutlet weak var flashButton: RoundedShadowButton!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var speechSynthesizer: AVSpeechSynthesizer!
    
    var photoData: Data?
    var flashMode: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        super.viewDidLoad()
        previewLayer.frame = cameraView.bounds
        speechSynthesizer.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        spinner.isHidden = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(đidTapCameraView))
        tap.numberOfTapsRequired = 1
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video) //use the video size
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            cameraOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(cameraOutput) {
                captureSession.addOutput(cameraOutput!)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                
                cameraView.layer.addSublayer(previewLayer!)
                cameraView.addGestureRecognizer(tap)
                captureSession.startRunning()
            }
        } catch {
            debugPrint(error)
        }
    }
    
    @objc func đidTapCameraView() {
        cameraView.isUserInteractionEnabled = false
        spinner.isHidden = false
        spinner.startAnimating()
        
        let settings = AVCapturePhotoSettings()
//        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
//        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
//                             kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 160]
        
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        
        if flashMode {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }

    @IBAction func toggleFlashMode(_ sender: RoundedShadowButton) {
        flashMode = !flashMode
        if flashMode {
            flashButton.backgroundColor = UIColor.white
            flashButton.setTitle("FLASH ON", for: UIControlState.normal)
        } else {
            flashButton.backgroundColor = UIColor.black
            flashButton.setTitle("FLASH OFF", for: UIControlState.normal)
        }
    }
    
    func resultsMethod(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else { return }
        
        for cls in results {
            //print(cls.identifier, cls.confidence)
            
            // the result is sorted by the confidence, desc
            // so just take the 1st result
            if cls.confidence < 0.5 {
                let msg = "I'm not sure. Please try again!"
                itemLabel.text = msg
                confidenceLabel.text = ""
                
                synthersizeSpeech(text: msg)
                break
            } else {
                let msg = "This looks like a \(cls.identifier). I'm \(Int(cls.confidence * 100)) sure"
                itemLabel.text = cls.identifier
                confidenceLabel.text = "CONFIDENCE: \(Int(cls.confidence * 100)) %"
                
                synthersizeSpeech(text: msg)
                break
            }
        }
    }
    
    func synthersizeSpeech(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechSynthesizer.speak(speechUtterance)
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            photoData = photo.fileDataRepresentation()
            
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultsMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                
                try handler.perform([request])
            } catch {
                debugPrint(error)
            }
            
            let image = UIImage(data: photoData!)
            capturedImageView.image = image
        }
        
    }
}

extension CameraViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        spinner.stopAnimating()
        cameraView.isUserInteractionEnabled = true
        spinner.isHidden = true
    }
}
