//
//  Epoch.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import Foundation
import ReactiveCocoa
import ReactiveSwift
import Result
import PromiseKit

/// An epoch is the smallest period of time we consider when computing
/// activity.
public struct Epoch {
    /// Start date of this epoch.
    public let start: Date
    /// End date of this epoch.
    public let end: Date
    
    /// Duration of the smallest fragment of time we are going to consider.
    public static let duration: Measurement<UnitDuration> = Measurement(
        value: 1,
        unit: UnitDuration.seconds
    )
    
    /// Current epoch, ending now and starting `now - epochDuration`.
    public static var current: Epoch {
        get {
            return Epoch(endingAt: Date())
        }
    }
    
    /// Creates a new epoch that ends at given date.
    /// - parameter end: Date when the epoch ends.
    /// - returns: Epoch ending at given date.
    public init(endingAt end: Date) {
        self.end = end
        let epochInSeconds = Epoch.duration.converted(to: .seconds).value
        self.start = end.addingTimeInterval(-1.0 * epochInSeconds)
    }
}

/// Statistics on a single epoch.
public typealias EpochStats = (bpm: Double, epoch: Epoch)

/// A tuple of HealthModel and a Signal with epoch stats.
public typealias SourceAndSignal<Source: EpochStatsSource> = (
    source: Source,
    epochStatsSignal: Signal<EpochStats, NoError>
)

/// Any type implementing this protocol can be used to get activity data stats.
public protocol EpochStatsSource {
    /// Returns activity statistics of given epoch.
    /// - parameter epoch: Only activity during given epoch will be considered.
    /// - returns: Given epoch statistics.
    func getStats(epoch: Epoch) -> Promise<EpochStats>
}

extension EpochStatsSource {
    /// Returns current epoch stats.
    /// - returns: Current epoch stats.
    func getCurrentEpochStats() -> Promise<EpochStats> {
        return self.getStats(epoch: Epoch.current)
    }
}
