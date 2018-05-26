//
//  CoreMotionModel.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import Foundation
import CoreMotion
import PromiseKit
import ReactiveCocoa
import ReactiveSwift
import Result

public struct CoreMotionModel: EpochStatsSource {
    /// Underlying pedometers used to query CoreMotion.
    public let pedometer: CMPedometer
    
    // MARK: - Private helpers
    
    /// QueueScheduler where background epoch calculations will be performed to
    /// not block UI thread.
    private static let epochStatsQueue: QueueScheduler = QueueScheduler(
        qos: .userInitiated,
        name: "coreMotionStats",
        targeting: nil
    )
    
    /// Signal which emits epochs continously.
    private static let epochsSignalProducer: SignalProducer<Epoch, NoError> = {
        let dispatchTimeInterval = DispatchTimeInterval.milliseconds(
            Int(Epoch.duration.converted(to: .seconds).value * 1000)
        )
        
        let dateSignalProducer = SignalProducer<Date, NoError>.timer(
            interval: dispatchTimeInterval,
            on: CoreMotionModel.epochStatsQueue
        )
        
        let epochSignalProducer = dateSignalProducer.map { date -> Epoch in
            Epoch(endingAt: date)
        }
        
        return epochSignalProducer
    }()
    
    // MARK: - Public
    
    /// Returns a promise that will be resolved with a new `CoreMotionModel`.
    /// - note: This method will ask for proper permissions and the promise will
    ///         be rejected if user does not allow the app to access activity
    ///         data.
    /// - returns: Promise that will be resolved with a new `CoreMotionModel`.
    static func buildCoreMotionModel () -> Promise<SourceAndSignal<CoreMotionModel>> {
        let (promise, resolver) = Promise<SourceAndSignal<CoreMotionModel>>.pending()
        
        let pedometer = CMPedometer()
        
        pedometer.queryPedometerData(from: Date(), to: Date()) { (optionalData, optionalError) in
            if let error = optionalError {
                resolver.reject(error)
                return
            }
            
            guard optionalData != nil else {
                resolver.reject(CoreMotionModelError.permissionsNotGiven)
                return
            }
            
            let coreMotionModel = CoreMotionModel(pedometer: pedometer)
            
            let epochStatsSignal: Signal<EpochStats, NoError> = {
                let (output, input) = Signal<EpochStats, NoError>.pipe()
                
                CoreMotionModel.epochsSignalProducer.startWithValues { epoch in
                    _ = coreMotionModel.getStats(epoch: epoch).done { stats in
                        input.send(value: stats)
                    }
                }
                
                return output
            }()
            
            // TODO: Enable background updates...
            
            resolver.fulfill((
                source: coreMotionModel,
                epochStatsSignal: epochStatsSignal
            ))
        }
        
        return promise
    }

    // MARK: - EpochStatsSource Protocol Methods

    public func getStats(epoch: Epoch) -> Promise<EpochStats> {
        let (promise, resolver) = Promise<EpochStats>.pending()
        
        self.pedometer.queryPedometerData(from: epoch.start, to: epoch.end) { (optionalData, optionalError) in
            if let error = optionalError {
                resolver.reject(error)
                return
            }
            
            guard let data = optionalData else {
                resolver.reject(CoreMotionModelError.unexpectedQueryError)
                return
            }
            
            let bpm: Double
            
            if let cadence = data.currentCadence {
                bpm = cadence.doubleValue
            } else {
                bpm = data.numberOfSteps.doubleValue
            }
            
            let epochStats: EpochStats = (bpm: bpm, epoch: epoch)
            
            resolver.fulfill(epochStats)
        }
        
        return promise
    }
}
