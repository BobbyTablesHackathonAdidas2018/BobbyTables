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

public struct HealthModel {
    /// Underlying store used to query Health Kit.
    public let healthStore: HKHealthStore
    /// Duration of the smallest fragment of time we are going to consider.
    private let epochDuration: Measurement<UnitDuration> = Measurement(
        value: 15,
        unit: UnitDuration.seconds
    )
    
    // MARK: - Private helpers
    
    /// An epoch is the smallest period of time we consider when computing
    /// activity.
    typealias Epoch = (start: Date, end: Date)
    
    /// Current epoch, ending now and starting `now - epochDuration`.
    private var currentEpoch: Epoch {
        get {
            let end = Date()
            let epochInSeconds = self.epochDuration.converted(to: .seconds).value
            let start = end.addingTimeInterval(-1.0 * epochInSeconds)
            return (start: start, end: end)
        }
    }
    
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
    
    // MARK: - Public
    
    /// Returns a promise that will be resolved with a new `HealthModel`.
    /// - note: This method will ask for proper permissions and the promise will
    ///         be rejected if user does not allow the app to access activity
    ///         data.
    /// - returns: Promise that will be resolved with a new `HealthModel`.
    static func buildHealthModel () -> Promise<HealthModel> {
        let (promise, resolver) = Promise<HealthModel>.pending()
        
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
            
            let instance = HealthModel(healthStore: healthStore)
            resolver.fulfill(instance)
        }
        
        return promise
    }
    
    /// Returns steps in current epoch.
    /// - returns: Promise that will be resolved with total amount of steps.
    public func getSteps () -> Promise<Int> {
        return self.getSteps(epoch: self.currentEpoch)
    }
}
