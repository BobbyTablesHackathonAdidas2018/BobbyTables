//
//  EntryViewController.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import UIKit
import GradientView

/// This VC ask user for permissions and shows a nice error message if user
/// doesn't give us access to her activity data.
class EntryViewController: UIViewController {
    
    @IBOutlet weak var gradientView: GradientView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.setBackgroundImage(UIColor.ezbeatGreen.image, for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        self.gradientView.colors = [UIColor.ezbeatBlue, UIColor.ezbeatGreen]
        self.gradientView.locations = [0.0, 1.0]
        self.gradientView.direction = .vertical
        
//        HealthModel.buildHealthModel().done { healthModelAndSignal in
//            let playerVC = PlayerViewController.instantiate(modelAndSignal: healthModelAndSignal)
//            UIApplication.shared.mainWindow?.rootViewController = playerVC
//        }.catch { error in
//            fatalError(error.localizedDescription)
//        }

        MusicModel.startSpotifyAuthenticationFlow { authenticationController in
            OperationQueue.main.addOperation {
                self.present(authenticationController, animated: true, completion: nil)
            }
        }.then {
            return CoreMotionModel.buildCoreMotionModel().done { coreMotionModelAndSignal in
                let playerVC = PlayerViewController.instantiate(modelAndSignal: coreMotionModelAndSignal)
                let rootViewController = UIApplication.shared.mainWindow!.rootViewController!
                if let navigationController = rootViewController as? UINavigationController {
                    navigationController.setViewControllers([playerVC], animated: true)
                } else {
                    UIApplication.shared.mainWindow!.rootViewController = playerVC
                }
            }
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
