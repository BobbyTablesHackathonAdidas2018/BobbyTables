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

typealias Source = CoreMotionModel // Just to make it easier to work with storyboards

/// This VC shows the main UI of the music player
final class PlayerViewController: UIViewController, StoryboardBased {
    @IBOutlet private weak var stepsLabel: UILabel!
    @IBOutlet private weak var debugLabel: UILabel!
    
    /// Data source feeding this controller with epoch statistics.
    private var source: EpochStatsSource!
    /// Disposable listening to new events emitted by the data source.
    private var epochStatsDisposable: Disposable!
    
    // MARK: -
    
    /// Returns a new instance properly initialized to get data from given source.
    /// - parameter modelAndSignal: Data source and event emitter used to feed this view controller.
    /// - returns: New properly initialized instance.
    static func instantiate(modelAndSignal: SourceAndSignal<Source>) -> PlayerViewController {
        let vc = PlayerViewController.instantiate()
        vc.source = modelAndSignal.source
        vc.epochStatsDisposable = modelAndSignal.epochStatsSignal.observeValues { epochStats in
            vc.handle(newEpochStats: epochStats)
        }
        return vc
    }
    
    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: Probably we don't want to start music until we start moving but...
        _ = MusicModel.replaceCurrentlyPlayingSong(with: Song.initialSong)
        // self.stepsLabel.text = "HOLA MUNDO"
        // self.reloadEpoch()
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
    
    // MARK: - User interaction handlers
    
    @IBAction private func reloadEpoch () {
        _ = self.source.getCurrentEpochStats().done { epochStats in
            self.handle(newEpochStats: epochStats, forceNewSongReload: true)
        }
    }
    
    // MARK: - UI Update Methods
    
    /// Handles an incoming epochStats, updating UI to reflect current data and
    /// recomputing next queued song if required.
    /// - parameter epochStats: Stats to be handled.
    /// - parameter forceNewSongReload: Pass `true` to force getting a new song
    /// regardless delta with respect to previous epoch.
    private func handle(
        newEpochStats epochStats: EpochStats,
        forceNewSongReload: Bool = false
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss zzz"
        
        self.debugLabel.text = epochStats.debugInfo
        self.stepsLabel.text = String(
            format: "Steps at %@: %.2f",
            dateFormatter.string(from: epochStats.epoch.end),
            epochStats.bpm
        )
        
        if
            !forceNewSongReload,
            let currentSong = MusicModel.currentlyPlayingSong,
            (currentSong.request?.epochStats ?? EpochStats.defaultStats) ~= epochStats, // If epochs are similar...
            let remainingPercent = MusicModel.currentlyPlayedSongRemainingPercent,
            remainingPercent > 0.15, // And there's still more than 15% of the song to play...
            let remainingDuration = MusicModel.currentlyPlayedSongRemainingDuration,
            remainingDuration > 30 // And there are still more than 30 seconds of song to play...
        {
            // ... then do nothing
            self.debugLabel.text = "\(epochStats.debugInfo)\n\nIgnoring requested update :)"
            print("Ignoring requested update")
            return
        }
        
        if (forceNewSongReload) {
            self.debugLabel.text = "\(epochStats.debugInfo)\n\nForcing new song!"
        }
        
        // TODO: We should probably check if we should start playing next song
        
        // Otherwise...
        // - if epochs are different
        // - or... there's less than 15% of the song to play
        // - or... there are less than 30 seconds of song remaining
        // ... get a new song and play it
        
        _ = MusicModel.getSong(
            for: epochStats,
            with: MusicModel.currentlyPlayingSong ?? Song.initialSong
        ).done { song in
            MusicModel.replaceEnqueuedSong(with: song)
        }
    }
}
