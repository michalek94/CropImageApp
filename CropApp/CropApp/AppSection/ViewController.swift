//
//  ViewController.swift
//  CropApp
//
//  Created by Michał Pankowski on 09/11/2019.
//  Copyright © 2019 Michał Pankowski. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            self.scrollView.delegate = self
            self.scrollView.minimumZoomScale = 1.0
            self.scrollView.maximumZoomScale = 10.0
        }
    }
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var takePhotoButton: UIButton!
    
    let imagePicker = UIImagePickerController()
    var circlePath = UIBezierPath()
    
    var cropArea: CGRect {
        get {
            let imageFrame = imageView.imageFrame()
            let x = (circlePath.bounds.origin.x - imageFrame.origin.x)
            let y = (circlePath.bounds.origin.y - imageFrame.origin.y)
            let width = circlePath.bounds.size.width
            let height = circlePath.bounds.size.height
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
    
    var captureSession: AVCaptureSession!
    var captureDevice: AVCaptureDevice!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.previewView.isHidden = false
        
        self.imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleBottomMargin, .flexibleRightMargin, .flexibleLeftMargin, .flexibleTopMargin]
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
        
        self.imagePicker.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.prepareCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
        self.toggleTorch(on: false)
    }
    
    @IBAction func takePhotoFromGallery(_ sender: UIButton) {
        self.imagePicker.sourceType = .photoLibrary
        self.present(self.imagePicker, animated: true)
    }
    
    @IBAction func cropImage(_ sender: UIButton) {
        if let image = self.imageView.image, let croppedCGImage = self.cropImage(image: image, rect: self.cropArea, scale: self.imageView.image?.scale ?? 1.0) {
            self.previewView.isHidden = true
            self.imageView.contentMode = .scaleAspectFit
            
            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = croppedCGImage
            }
            
            self.scrollView.zoomScale = 1.0
            
            let _ = self.view.layer.sublayers?.popLast()
        } else {
            print("You need to take photo first!!")
        }
    }
    
    @IBAction func takePhotoFromCamera(_ sender: UIButton) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        self.stillImageOutput.capturePhoto(with: settings, delegate: self)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.takePhotoButton.isHidden = true
            self?.previewView.isHidden = true
        }
        
        let size: CGFloat = 200
        self.layer(x: ((self.view.frame.size.width) / 2) - (size / 2),
                   y: ((self.view.frame.size.height) / 2) - (size / 2),
                   width: size,
                   height: size,
                   cornerRadius: 0)
    }
    
    @IBAction func savePhoto(_ sender: UIButton) {
        if let image = self.imageView.image {
            self.savePhotoToAlbum(image: image)
        } else {
            print("You need to take photo first!!")
        }
    }
    
    @IBAction func cleanArea(_ sender: UIButton) {
        self.scrollView.zoomScale = 1.0
        self.imageView.image = nil
        self.previewView.isHidden = false
        self.takePhotoButton.isHidden = false
    }
    
    @IBAction func light(_ sender: UIButton) {
        self.toggleTorch(on: self.captureDevice.torchMode == .off)
    }
    
    private func toggleTorch(on: Bool = false) {
        guard let device = captureDevice else { return }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if on {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used!")
            }
        } else {
            print("Torch is not available!")
        }
    }
    
    private func savePhotoToAlbum(image: UIImage) {
        let savingPhotoAlert = UIAlertController(title: "Save photo", message: "Do you want to save photo to photo album?", preferredStyle: .alert)
        
        savingPhotoAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            // clean screen
            self.scrollView.zoomScale = 1.0
            self.imageView.image = nil
            self.previewView.isHidden = false
            self.takePhotoButton.isHidden = false
        }))
        
        savingPhotoAlert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { action in
            // clean screen
            self.scrollView.zoomScale = 1.0
            self.imageView.image = nil
            self.previewView.isHidden = false
            self.takePhotoButton.isHidden = false
        }))
        
        self.present(savingPhotoAlert, animated: true)
    }
    
    private func prepareCamera() {
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = .photo
        
        self.captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            self.stillImageOutput = AVCapturePhotoOutput()
            
            if self.captureSession.canAddInput(input) && self.captureSession.canAddOutput(self.stillImageOutput) {
                self.captureSession.addInput(input)
                self.captureSession.addOutput(self.stillImageOutput)
                self.setupLivePreview()
            }
        } catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }
    
    private func setupLivePreview() {
        self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.videoPreviewLayer.videoGravity = .resizeAspectFill
        self.videoPreviewLayer.connection?.videoOrientation = .portrait
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                let bounds: CGRect = self.previewView.layer.bounds
                
                self.videoPreviewLayer.bounds = bounds
                self.videoPreviewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
                
                self.previewView.layer.addSublayer(self.videoPreviewLayer)
            }
        }
    }
    
    private func layer(x: CGFloat,y: CGFloat, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) {
        var path: UIBezierPath
        var topSafeArea: CGFloat
        var bottomSafeArea: CGFloat
        let buttonsAreaHeight: CGFloat = 36.0

        if #available(iOS 11.0, *) {
            topSafeArea = view.safeAreaInsets.top
            bottomSafeArea = view.safeAreaInsets.bottom
            path = UIBezierPath(roundedRect: CGRect(x: 0, y: topSafeArea + buttonsAreaHeight, width: self.view.bounds.size.width, height: self.view.bounds.size.height - buttonsAreaHeight - topSafeArea - 2 * bottomSafeArea), cornerRadius: 0)
        } else {
            path = UIBezierPath(roundedRect: CGRect(x: 0, y: buttonsAreaHeight, width: self.view.bounds.size.width, height: self.view.bounds.size.height - 2*buttonsAreaHeight), cornerRadius: 0) // not tested, have no devices without safe area :(
        }

        self.circlePath = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: cornerRadius)
        
        path.append(self.circlePath)
        path.usesEvenOddFillRule = true
        
        let fillLayer = CAShapeLayer()
        fillLayer.path = path.cgPath
        fillLayer.fillRule = CAShapeLayerFillRule.evenOdd
        fillLayer.opacity = 0.7
        fillLayer.fillColor = UIColor.lightGray.cgColor
        
        view.layer.addSublayer(fillLayer)
    }
    
    private func cropImage(image: UIImage, rect: CGRect, scale: CGFloat) -> UIImage? {
        let mainScale = UIScreen.main.scale
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: rect.size.width / 1, height: rect.size.height / 1), false, mainScale * 1)
        
        let context = UIGraphicsGetCurrentContext()!
        let y = -rect.origin.y - imageView.imageFrame().origin.y
        let x = -rect.origin.x - imageView.imageFrame().origin.x
        
        context.translateBy(x: x, y: y)
        
        self.view.layer.render(in: context)
        
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        imageView.image = croppedImage
        imageView.contentMode = .scaleAspectFit
        
        UIGraphicsEndImageContext()
        
        return croppedImage
    }
    
}

extension ViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
}

extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let selectedImage = info[.originalImage] as? UIImage else {
            fatalError("Expected a dictionary containing an image, but was provided the following: \(info)")
        }
        
        self.dismiss(animated: true, completion: { [weak self] in
            self?.imageView.image = selectedImage
            self?.previewView.isHidden = true
            self?.takePhotoButton.isHidden = true
            
            let size: CGFloat = 200
            self?.layer(x: ((self?.view.frame.size.width ?? 0) / 2) - (size / 2),
                        y: ((self?.view.frame.size.height ?? 0) / 2) - (size / 2),
                        width: size,
                        height: size,
                        cornerRadius: 0)
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        let image = UIImage(data: imageData)
        self.imageView.image = image
    }
    
}
