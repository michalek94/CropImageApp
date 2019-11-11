//
//  UIImage+Resize.swift
//  CropApp
//
//  Created by Michał Pankowski on 11/11/2019.
//  Copyright © 2019 Michał Pankowski. All rights reserved.
//

import UIKit

extension UIImage {
    
    func resizeImage(targetSize: CGSize) -> UIImage {
        let originalSize = self.size
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, UIScreen.main.scale)
        self.draw(in: rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
}
