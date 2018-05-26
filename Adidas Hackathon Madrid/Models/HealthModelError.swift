//
//  HealthModelError.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import Foundation

enum HealthModelError: Error {
    case permissionsNotGiven
    case unknownQuantityType
    case unexpectedQueryError
}
