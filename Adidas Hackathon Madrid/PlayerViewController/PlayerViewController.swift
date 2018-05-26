//
//  PlayerViewController.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import UIKit
import Reusable
import ReactiveSwift

/// This VC shows the main UI of the music player
final class PlayerViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private weak var stepsLabel: UILabel!
    private var healthModel: HealthModel!
    private var epochStatsDisposable: Disposable!
   
    // This is here just to demo
    private var maxBMP: Double = 0
    
    static func instantiate(healthModelAndSignal: HealthModelAndSignal) -> PlayerViewController {
        let vc = PlayerViewController.instantiate()
        vc.healthModel = healthModelAndSignal.healthModel
        vc.epochStatsDisposable = healthModelAndSignal.epochStatsSignal.observeValues { epochStats in
            vc.handle(newEpochStats: epochStats)
        }
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
    
    // MARK: - UI Update Methods
    
    /// Handles an incoming epochStats, updating UI to reflect current data and
    /// recomputing next queued song if required.
    /// - parameter epochStats: Stats to be handled.
    private func handle(newEpochStats epochStats: EpochStats) {
        // TODO: Do something
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss zzz"
        
        self.maxBMP = max(self.maxBMP, epochStats.bpm)
        
        self.stepsLabel.text = String(
            format: "Steps at %@: %.2f",
            dateFormatter.string(from: epochStats.epoch.end),
            self.maxBMP
        )
    }
}

