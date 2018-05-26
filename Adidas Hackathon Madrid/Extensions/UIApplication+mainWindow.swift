//
//  UIApplication+mainWindow.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import UIKit

extension UIApplication {
    /// UIApplication's delegate window.
    var mainWindow: UIWindow? {
        get {
            guard let delegate = self.delegate else {
                return nil
            }
            guard let window = delegate.window else {
                return nil
            }
            return window
        }
    }
}
