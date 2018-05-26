//
//  PlayerViewController.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import UIKit
import Reusable

/// This VC shows the main UI of the music player
final class PlayerViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private weak var stepsLabel: UILabel!
    private var healthModel: HealthModel!
    
    static func instantiate(healthModel: HealthModel) -> PlayerViewController {
        let vc = PlayerViewController.instantiate()
        vc.healthModel = healthModel
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.stepsLabel.text = "HOLA MUNDO"
        self.reloadSteps()
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
    
    @IBAction private func reloadSteps () {
        _ = self.healthModel.getSteps().done { steps in
            self.stepsLabel.text = String(format: "Steps: %d", steps)
        }
    }
}

