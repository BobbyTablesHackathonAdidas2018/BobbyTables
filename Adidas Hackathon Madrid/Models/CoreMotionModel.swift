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
    
    /// Signal emitting pedometer data and holding last emitted value.
    private let currentPedometerData: Property<CMPedometerData>
    
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
    
    // MARK: -
    
    /// Returns a new EpochStats from given data from pedometer.
    /// - parameter pedometerData: Data from pedometer.
    private static func getEpochStats(from pedometerData: CMPedometerData) -> EpochStats {
        let epoch = Epoch(
            startingAt: pedometerData.startDate,
            endingAt: pedometerData.endDate
        )
        
        let bps: Double
        let debugInfo: String
        if let cadence = pedometerData.currentCadence {
            bps = cadence.doubleValue
            debugInfo = "Using CADENCE"
        } else {
            let steps = pedometerData.numberOfSteps.doubleValue
            bps = steps / epoch.duration
            debugInfo = "Using number of steps"
        }
        
        return (bpm: bps * 60, debugInfo: debugInfo, epoch: epoch)
    }
    
    // MARK: - Public
    
    /// Returns a promise that will be resolved with a new `CoreMotionModel`.
    /// - note: This method will ask for proper permissions and the promise will
    ///         be rejected if user does not allow the app to access activity
    ///         data.
    /// - returns: Promise that will be resolved with a new `CoreMotionModel`.
    static func buildCoreMotionModel () -> Promise<SourceAndSignal<CoreMotionModel>> {
        let (promise, resolver) = Promise<SourceAndSignal<CoreMotionModel>>.pending()
        
        let pedometer = CMPedometer()
        
        let (
            pedometerDataSignalOutput,
            pedometerDataSignalInput
        ) = Signal<CMPedometerData, NoError>.pipe()
        
        
        
        pedometer.startUpdates(from: Date()) { (optionalData, optionalError) in
            print("PEDOMETER GAVE DATA!!!!")
            
            if let error = optionalError {
                print(error.localizedDescription)
                return
            }

            guard let data = optionalData else {
                print("No data received from pedometer")
                return
            }
            
            pedometerDataSignalInput.send(value: data)
        }
        
        let epoch = Epoch.current
        
        pedometer.queryPedometerData(from: epoch.start, to: epoch.end) { (optionalData, optionalError) in
            if let error = optionalError {
                resolver.reject(error)
                return
            }
            
            guard let data = optionalData else {
                resolver.reject(CoreMotionModelError.permissionsNotGiven)
                return
            }
            
            let coreMotionModel = CoreMotionModel(
                pedometer: pedometer,
                currentPedometerData: Property<CMPedometerData>(
                    initial: data,
                    then: pedometerDataSignalOutput
                )
            )
            
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
        return Promise<EpochStats>.value(CoreMotionModel.getEpochStats(from: self.currentPedometerData.value))
    }
}
