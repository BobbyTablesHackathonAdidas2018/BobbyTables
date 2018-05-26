//
//  EntryViewController.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import UIKit

/// This VC ask user for permissions and shows a nice error message if user
/// doesn't give us access to her activity data.
class EntryViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let mainWindow = UIApplication.shared.mainWindow else {
            fatalError("App does not have keyWindow")
        }
        
        HealthModel.buildHealthModel().done { model in
            let playerVC = PlayerViewController.instantiate(healthModel: model)
            mainWindow.rootViewController = playerVC
        }.catch { error in
            fatalError(error.localizedDescription)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}
