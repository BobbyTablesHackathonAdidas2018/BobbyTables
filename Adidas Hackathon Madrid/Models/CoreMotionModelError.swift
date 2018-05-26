//
//  CoreMotionModelError.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import Foundation

/// Possible errors produced by CoreMotion model.
/// - `permissionsNotGiven`: User didn't give permissions to get motion data.
/// - `noDataAvailable`: No motion data has been emitted yet.
/// - `unexpectedQuery`: Historical data query failed.
enum CoreMotionModelError: Error {
    case permissionsNotGiven
    case noDataAvailable
    case unexpectedQuery
}
