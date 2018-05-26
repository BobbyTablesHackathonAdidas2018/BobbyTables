//
//  MusicModelError.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import Foundation

/// Possible errors thrown by MusicModel.
/// - `unhandlableAuthenticationCallbackURL`: given callback's URL is not valid.
/// - `unexpectedSpotifySessionValidation`: unexpected error when validating Spotify session.
/// - `noNextSongAvailable`: there's no next song available to play.
/// - `unparseableBackendResponse`: backend returned a non-parseable object.
enum MusicModelError: Error {
    case unhandlableAuthenticationCallbackURL
    case unexpectedSpotifySessionValidation
    case noNextSongAvailable
    case unparseableBackendResponse
}
