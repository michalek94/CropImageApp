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
    
    let borderLayer = CAShapeLayer()
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
        set {}
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
        self.scrollView.isUserInteractionEnabled = false
        
        self.takePhotoButton.layer.cornerRadius = takePhotoButton.frame.height/2
        self.takePhotoButton.layer.borderWidth = 2.0
        self.takePhotoButton.layer.borderColor = UIColor.white.cgColor
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        let screenSize = self.previewView.bounds.size
        if let touchPoint = touches.first {
            let x = touchPoint.location(in: self.previewView).y / screenSize.height
            let y = 1.0 - touchPoint.location(in: self.previewView).x / screenSize.width
            let focusPoint = CGPoint(x: x, y: y)
            
            if let device = captureDevice {
                do {
                    try device.lockForConfiguration()
                    
                    if device.isFocusPointOfInterestSupported {
                        let viewTouchSize = CGSize(width: 72.0, height: 72.0)
                        let focusViewPoint = CGPoint(x: touchPoint.location(in: self.previewView).x - viewTouchSize.width/2, y: touchPoint.location(in: self.previewView).y - viewTouchSize.height/2)
                        let viewTouch = UIView(frame: CGRect(origin: focusViewPoint, size: CGSize(width: viewTouchSize.width, height: viewTouchSize.height)))
                        
                        viewTouch.layer.cornerRadius = viewTouch.frame.height/2
                        viewTouch.layer.borderWidth = 2.0
                        viewTouch.layer.borderColor = UIColor.white.cgColor
                        viewTouch.backgroundColor = .clear
                        
                        self.imageView.addSubview(viewTouch)
                        
                        self.view.setNeedsLayout()
                        self.view.layoutIfNeeded()
                        
                        device.focusPointOfInterest = focusPoint
                        device.focusMode = .autoFocus
                        device.exposurePointOfInterest = focusPoint
                        device.exposureMode = .continuousAutoExposure
                        device.unlockForConfiguration()
                    }
                }
                catch {}
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if let _ = touches.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.imageView.subviews.first?.removeFromSuperview()
            }
        }
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
        } else {
            print("You need to take photo first!!")
        }
    }
    
    @IBAction func takePhotoFromCamera(_ sender: UIButton) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        self.stillImageOutput.capturePhoto(with: settings, delegate: self)
        
        self.scrollView.isUserInteractionEnabled = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
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
        self.scrollView.isUserInteractionEnabled = false
        
        self.view.layer.sublayers?.removeAll(where: { [weak self] layer -> Bool in
            return layer == self?.borderLayer
        })
    }
    
    @IBAction func light(_ sender: UIButton) {
        self.toggleTorch(on: self.captureDevice.torchMode == .off)
    }
    
    @IBAction func switchCamera(_ sender: UIButton) {
        if let session = captureSession {
            let currentCameraInput: AVCaptureInput = session.inputs[0]
            var newCamera: AVCaptureDevice
            newCamera = AVCaptureDevice.default(for: AVMediaType.video)!
            
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            
            if (currentCameraInput as! AVCaptureDeviceInput).device.position == .back {
                UIView.transition(with: self.previewView, duration: 0.5, options: .transitionFlipFromLeft, animations: { [weak self] in
                    guard let self = self else { return }
                    newCamera = self.cameraWithPosition(.front)!
                })
            } else {
                UIView.transition(with: self.previewView, duration: 0.5, options: .transitionFlipFromRight, animations: { [weak self] in
                    guard let self = self else { return }
                    newCamera = self.cameraWithPosition(.back)!
                })
            }
            
            session.removeInput(currentCameraInput)
            
            do {
                try session.addInput(AVCaptureDeviceInput(device: newCamera))
                
            } catch {
                print("error: \(error.localizedDescription)")
            }
            
            session.commitConfiguration()
        }
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
            self.scrollView.zoomScale = 1.0
            self.imageView.image = nil
            self.previewView.isHidden = false
        }))
        
        savingPhotoAlert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { action in
            self.scrollView.zoomScale = 1.0
            self.imageView.image = nil
            self.previewView.isHidden = false
        }))
        
        self.scrollView.isUserInteractionEnabled = false
        self.present(savingPhotoAlert, animated: true)
    }
    
    private func prepareCamera() {
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = .photo
        
        self.captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
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
        let path: UIBezierPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height), cornerRadius: 0)
        
        self.circlePath = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: cornerRadius)
        
        path.append(self.circlePath)
        path.usesEvenOddFillRule = true
        
        self.borderLayer.path = circlePath.cgPath
        self.borderLayer.lineWidth = 2
        self.borderLayer.strokeColor = UIColor.red.cgColor
        self.borderLayer.fillColor = UIColor.clear.cgColor
        
        view.layer.addSublayer(borderLayer)
    }
    
    private func cropImage(image: UIImage, rect: CGRect, scale: CGFloat) -> UIImage? {
        let mainScale = UIScreen.main.scale
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: rect.size.width / 1, height: rect.size.height / 1), false, mainScale * 1)
        
        let context = UIGraphicsGetCurrentContext()!
        let y = -rect.origin.y - imageView.imageFrame().origin.y
        let x = -rect.origin.x - imageView.imageFrame().origin.x
        
        context.translateBy(x: x, y: y)
        
        self.view.layer.sublayers?.removeAll(where: { layer -> Bool in
            return layer == borderLayer
        })
        
        self.view.layer.render(in: context)
        
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        imageView.image = croppedImage
        imageView.contentMode = .scaleAspectFit
        
        UIGraphicsEndImageContext()
        
        return croppedImage
    }
    
    
    private func cameraWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        
        for device in deviceDescoverySession.devices {
            if device.position == position {
                return device
            }
        }
        
        return nil
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
            self?.scrollView.isUserInteractionEnabled = true
            
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
