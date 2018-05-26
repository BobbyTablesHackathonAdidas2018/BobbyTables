//
//  HealthModel.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import Foundation
import HealthKit
import PromiseKit
import ReactiveCocoa
import ReactiveSwift
import Result

/// An epoch is the smallest period of time we consider when computing
/// activity.
public typealias Epoch = (start: Date, end: Date)

/// Statistics on a single epoch.
public typealias EpochStats = (bpm: Double, epoch: Epoch)

/// A tuple of HealthModel and a Signal with epoch stats.
public typealias HealthModelAndSignal = (
    healthModel: HealthModel,
    epochStatsSignal: Signal<EpochStats, NoError>
)

public struct HealthModel {
    /// Underlying store used to query Health Kit.
    public let healthStore: HKHealthStore
    /// Duration of the smallest fragment of time we are going to consider.
    private static let epochDuration: Measurement<UnitDuration> = Measurement(
        value: 1,
        unit: UnitDuration.seconds
    )
    
    // MARK: - Private helpers
    
    /// QueueScheduler where background epoch calculations will be performed to
    /// not block UI thread.
    private static let epochStatsQueue: QueueScheduler = QueueScheduler(
        qos: .userInitiated,
        name: "epochStatsQueue",
        targeting: nil
    )
    
    /// Returns an epoch that ends at given date.
    /// - parameter end: Date when the epoch ends.
    /// - returns: Epoch ending at given date.
    private static func epoch(endingAt end: Date) -> Epoch {
        let epochInSeconds = HealthModel.epochDuration.converted(to: .seconds).value
        let start = end.addingTimeInterval(-1.0 * epochInSeconds)
        return (start: start, end: end)
    }
    
    /// Current epoch, ending now and starting `now - epochDuration`.
    private static var currentEpoch: Epoch {
        get {
            return self.epoch(endingAt: Date())
        }
    }
    
    /// Signal which emits epochs continously.
    private static let epochsSignalProducer: SignalProducer<Epoch, NoError> = {
        let dispatchTimeInterval = DispatchTimeInterval.milliseconds(
            Int(HealthModel.epochDuration.converted(to: .seconds).value * 1000)
        )
        
        let dateSignalProducer = SignalProducer<Date, NoError>.timer(
            interval: dispatchTimeInterval,
            on: HealthModel.epochStatsQueue
        )
        
        let epochSignalProducer = dateSignalProducer.map { date -> Epoch in
            HealthModel.epoch(endingAt: date)
        }
        
        return epochSignalProducer
    }()
    
    // MARK: - Queries
    
    /// Returns steps in given epoch.
    /// - parameter epoch: Only measurements in given epoch will be considered.
    /// - returns: Promise that will be resolved with total amount of steps.
    private func getSteps (epoch: Epoch) -> Promise<Int> {
        let (promise, resolver) = Promise<Int>.pending()
        
        guard let sampleType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            resolver.reject(HealthModelError.unknownQuantityType)
            return promise
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: epoch.start,
            end: epoch.end,
            options: []
        )
        
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { (sampleQuery, optionalSamples, optionalError) in
            if let error = optionalError {
                resolver.reject(error)
                return
            }
            
            guard let samples = optionalSamples else {
                resolver.reject(HealthModelError.unexpectedQueryError)
                return
            }
            
            let steps = samples.reduce(0, { (prev, sample) in
                guard let quantitySample = sample as? HKQuantitySample else {
                    // Ignorining non-quantity sample
                    return prev
                }
                let value = quantitySample.quantity.doubleValue(for: HKUnit.count())
                return prev + Int(value)
            })
            
            resolver.fulfill(steps)
            
            print(samples)
        }
        
        self.healthStore.execute(query)
        
        return promise
    }
    
    /// Returns epoch stats of given epoch.
    /// - parameter epoch: Only measurements in given epoch will be considered.
    /// - returns: Promise that will be resolved with stats of given epoch.
    private func getEpochStats (epoch: Epoch) -> Promise<EpochStats> {
        return self.getSteps().then { stepCount in
            // TODO: Compute BPM instead of returning just step count
            return Promise<EpochStats>.value((bpm: Double(stepCount), epoch: epoch))
        }
    }
    
    // MARK: - Public
    
    /// Returns a promise that will be resolved with a new `HealthModel`.
    /// - note: This method will ask for proper permissions and the promise will
    ///         be rejected if user does not allow the app to access activity
    ///         data.
    /// - returns: Promise that will be resolved with a new `HealthModel`.
    static func buildHealthModel () -> Promise<HealthModelAndSignal> {
        let (promise, resolver) = Promise<HealthModelAndSignal>.pending()
        
        let healthStore = HKHealthStore()
        
        let allTypes = Set([
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ])
        
        healthStore.requestAuthorization(toShare: nil, read: allTypes) {
            (success, error) in
            
            guard success else {
                resolver.reject(HealthModelError.permissionsNotGiven)
                return
            }
            
            let healthModel = HealthModel(healthStore: healthStore)
            
            let epochStatsSignal: Signal<EpochStats, NoError> = {
                let (output, input) = Signal<EpochStats, NoError>.pipe()
                
                HealthModel.epochsSignalProducer.startWithValues { epoch in
                    _ = healthModel.getEpochStats(epoch: epoch).done { stats in
                        input.send(value: stats)
                    }
                }
                
                return output
            }()
            
            resolver.fulfill((
                healthModel: healthModel,
                epochStatsSignal: epochStatsSignal
            ))
        }
        
        return promise
    }
    
    /// Returns steps in current epoch.
    /// - returns: Promise that will be resolved with total amount of steps.
    public func getSteps () -> Promise<Int> {
        return self.getSteps(epoch: HealthModel.currentEpoch)
    }
}
