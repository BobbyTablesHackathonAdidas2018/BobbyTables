//
//  UIColor+toImage.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 27/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import UIKit

extension UIColor {
    /// Image of 1x1px with this color as background.
    public var image: UIImage? {
        get {
            
            let rect = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
            self.setFill()
            UIRectFill(rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let cgImage = image?.cgImage else {
                return nil
            }
            
            return UIImage(cgImage: cgImage)
        }
    }
}
