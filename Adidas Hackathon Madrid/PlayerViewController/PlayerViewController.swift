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
import PromiseKit
import AlamofireImage
import Alamofire
import GradientView

typealias Source = CoreMotionModel // Just to make it easier to work with storyboards

/// This VC shows the main UI of the music player
final class PlayerViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private weak var stepsLabel: UILabel!
    @IBOutlet private weak var debugLabel: UILabel!
    @IBOutlet private weak var artworkImageView: UIImageView!
    @IBOutlet private weak var songTitleLabel: UILabel!
    @IBOutlet private weak var artistNameLabel: UILabel!
    @IBOutlet private weak var beginRunButtonLabel: UILabel!
    @IBOutlet private weak var gradientView: GradientView!
    
    /// Number formatter for bpm.
    private let bpmFormatter: NumberFormatter = {
        let bpmFormatter = NumberFormatter()
        bpmFormatter.minimumIntegerDigits = 1
        bpmFormatter.minimumFractionDigits = 2
        bpmFormatter.maximumFractionDigits = 2
        return bpmFormatter
    }()
    
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

        self.stepsLabel.text = self.bpmFormatter.string(from: NSNumber(value: 0))
        self.debugLabel.isHidden = true
        self.songTitleLabel.text = nil
        self.artistNameLabel.text = nil

        self.navigationController?.navigationBar.setBackgroundImage(UIColor.ezbeatBlue.image, for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        self.gradientView.colors = [UIColor.ezbeatBlue, UIColor.ezbeatGreen]
        self.gradientView.locations = [0.0, 1.0]
        self.gradientView.direction = .vertical
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
    
    @IBAction private func playNextSong () {
        guard MusicModel.currentlyPlayingSong != nil else {
            // If nothing is being played then we start running
            _ = MusicModel.replaceCurrentlyPlayingSong(with: Song.initialSong).done { song in
                self.show(song: song)
            }
            return
        }
        
        _ = self.source.getCurrentEpochStats().done { epochStats in
            self.handle(newEpochStats: epochStats, forceNewSongReload: true)
        }
    }
    
    /// Shows metadata of given show in UI.
    /// - parameter song: Song to be displayed.
    private func show(song: Song) {
        _ = MusicModel.replaceCurrentlyPlayingSong(with: song)
        self.songTitleLabel.text = song.name
        self.artistNameLabel.text = song.artistName
        self.beginRunButtonLabel.text = NSLocalizedString(
            "NEXT SONG",
            comment: "Title of next song button"
        )
        Alamofire.request(song.artworkURL).responseImage { response in
            guard let image = response.value, self.songTitleLabel.text == song.name else {
                return
            }
            self.artworkImageView.image = image
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
        self.stepsLabel.text = bpmFormatter.string(from: NSNumber(value: epochStats.bpm))
        
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
            self.debugLabel.text = "\(dateFormatter.string(from: epochStats.epoch.end)) \(epochStats.debugInfo)\n\nIgnoring requested update :)"
            print("Ignoring requested update")
            return
        }
        
        if (forceNewSongReload) {
            self.debugLabel.text = "\(dateFormatter.string(from: epochStats.epoch.end)) \(epochStats.debugInfo)\n\nForcing new song!"
            _ = MusicModel.playNext().done { song in
                self.show(song: song)
            }
        } else {
            self.maybeChangeSong(epochStats: epochStats)
        }
        
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
    
    /// Check if currently played song should be changed and changes it.
    /// - parameter triggeringEpoch: stats which triggered this potential update.
    private func maybeChangeSong (epochStats triggeringEpoch: EpochStats) {
        
        let now = Date()
        let fiveSecondsAgo = now.addingTimeInterval(-5)
        let tenSecondsAgo = now.addingTimeInterval(-10)
        let fifteenSecondsAgo = now.addingTimeInterval(-15)
        
        let last5Seconds = Epoch(startingAt: fiveSecondsAgo, endingAt: now)
        let last10Seconds = Epoch(startingAt: tenSecondsAgo, endingAt: fiveSecondsAgo)
        let last15Seconds = Epoch(startingAt: fifteenSecondsAgo, endingAt: tenSecondsAgo)
        
        _ = when(fulfilled: [
            self.source.getStats(epoch: last5Seconds),
            self.source.getStats(epoch: last10Seconds),
            self.source.getStats(epoch: last15Seconds)
        ]).done { results in
            guard MusicModel.hasNextSong else {
                print("NOT changing played song because NOTHING WAS ENQUEUED")
                return
            }
            
            guard let song = MusicModel.currentlyPlayingSong else {
                print("NOT changing played song because NOTHING WAS BEING PLAYED")
                return
            }
            
            guard let request = song.request else {
                print("CHANGING played song because INITIAL SONG was being played")
                _ = MusicModel.playNext().done { song in
                    self.show(song: song)
                }
                return
            }
            
            var recentEpochsAreSimilar = true
            for (index, currentEpoch) in results.dropLast().enumerated() {
                let nextEpoch = results[index + 1]
                print("Comparing history: \(currentEpoch.bpm) vs \(nextEpoch.bpm) -> \(currentEpoch ~= nextEpoch)")
                recentEpochsAreSimilar = recentEpochsAreSimilar && currentEpoch ~= nextEpoch
            }
            
            // Otherwise ensure the old epoch if different enough.
            if request.epochStats ~= triggeringEpoch {
                print("NOT changing played song because epoch stats didn't change enough")
                return
            }
            
            print("CHANGING played song because EPOCH CHANGED: \(request.epochStats.bpm) vs \(triggeringEpoch.bpm)")
            
            _ = MusicModel.playNext().done { song in
                self.show(song: song)
            }
        }
    }
}
