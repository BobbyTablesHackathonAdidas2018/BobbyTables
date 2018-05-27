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
    
    /// Creates a new epoch that starts and ends at given dates.
    /// - parameter start: Date when the epoch starts.
    /// - parameter end: Date when the epoch ends.
    /// - returns: Epoch ending at given date.
    public init(startingAt start: Date, endingAt end: Date) {
        self.start = start
        self.end = end
    }
    
    /// Creates a new epoch that ends at given date.
    /// - parameter end: Date when the epoch ends.
    /// - returns: Epoch ending at given date.
    public init(endingAt end: Date) {
        self.end = end
        let epochInSeconds = Epoch.duration.converted(to: .seconds).value
        self.start = end.addingTimeInterval(-1.0 * epochInSeconds)
    }
    
    /// Duration of this time interval.
    public var duration: TimeInterval {
        get {
            return self.end.timeIntervalSince(self.start)
        }
    }
}

/// Statistics on a single epoch.
public struct EpochStats {
    /// Beats per minute.
    public let bpm: Double
    /// Epoch.
    public let epoch: Epoch
    /// Debug information.
    public let debugInfo: String
    /// Default EpochStats.
    public static var defaultStats: EpochStats {
        get {
            return EpochStats(bpm: 0, epoch: Epoch.current, debugInfo: "")
        }
    }
}

/// Returns whether two EpochStats are similar or not.
/// - parameter lhs: Left hand side epoch to compare.
/// - parameter rhs: Right hand side epoch to compare.
/// - returns: `true` is both epochs are really similar.
public func ~=(lhs: EpochStats, rhs: EpochStats) -> Bool {
    let maxBpm = max(lhs.bpm, rhs.bpm)
    guard maxBpm > 0 else {
        return true
    }
    let diffBpm = abs(lhs.bpm - rhs.bpm)
    return diffBpm / maxBpm < 0.15
}

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

/// Background queue used to query epoch data sources.
private let backgroundQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "epochBackgroundQueue"
    queue.qualityOfService = .userInitiated
    return queue
}()

extension EpochStatsSource {
    /// Returns current epoch stats.
    /// - returns: Current epoch stats.
    func getCurrentEpochStats() -> Promise<EpochStats> {
        let (promise, resolver) = Promise<EpochStats>.pending()
        
        let epoch = Epoch.current
        backgroundQueue.addOperation {
            self.getStats(epoch: epoch)
                .done(resolver.fulfill)
                .catch(resolver.reject)
        }
        
        return promise
    }
}
