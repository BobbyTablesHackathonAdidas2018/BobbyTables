//
//  MusicModel.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit
import Haneke

/// Base URL to our API.
private let backendBaseURL: URL = URL(string: "http://52.31.62.57")!

/// A NumberFormatter which prints numbers as integers.
let integerNumberFormatter: NumberFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.maximumFractionDigits = 0
    numberFormatter.minimumIntegerDigits = 1
    return numberFormatter
}()

/// Data structure holding parameters required to perform a request to our backend.
public struct SongRequest {
    /// Stats of epoch for which we want a song.
    public let epochStats: EpochStats
    /// Song previously being played.
    public let previousSong: Song
    
    public var parameters: [String: String] {
        get {
            return [
                "bpm": integerNumberFormatter.string(from: NSNumber(floatLiteral: self.epochStats.bpm))!,
                "song": self.previousSong.name
            ]
        }
    }
    
    /// Returns a key for caching this request.
    public var cacheKey: String {
        get {
            return String(format: "song::%@::--bpm--::%.0f", self.epochStats.bpm)
        }
    }
}

/// Data structure holding metadata of a Spotify song.
public class Song: DataRepresentable, DataConvertible, NSCoding {
    /// URI of this song in Spotify.
    public let spotifyURI: String
    /// Name of this song.
    public let name: String
    
    public init(spotifyURI: String, name: String) {
        self.spotifyURI = spotifyURI
        self.name = name
    }
    
    // MARK: - First Song
    
    /// Initial song of a running session.
    public static var initialSong: Song {
        get {
            return Song(spotifyURI: "", name: "Enter Sandman")
        }
    }
    
    // MARK: -
    
    /// Key used to encode `spotifyURI` attribute in NSCoder.
    private static let spotifyURIKey: String = "spotifyURI"
    /// Key used to encode `name` attribute in NSCoder.
    private static let nameKey: String = "name"
    
    // MARK: - NSCoding Protocol Methods
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.spotifyURI, forKey: Song.spotifyURIKey)
        aCoder.encode(self.name, forKey: Song.nameKey)
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard
            let spotifyURI = aDecoder.decodeObject(forKey: Song.spotifyURIKey) as? String,
            let name = aDecoder.decodeObject(forKey: Song.nameKey) as? String
        else {
            return nil
        }
        
        self.init(spotifyURI: spotifyURI, name: name)
    }
    
    // MARK: - DataConvertible Protocol Methods
    
    public static func convertFromData(_ data: Data) -> Song? {
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? Song
    }
    
    public func asData() -> Data! {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}

/// This struct allows managing songs.
struct MusicModel {
    /// Cache of previously performed requests.
    private static let cache = Cache<Song>(name: "requests")
    
    /// Gets the proper song for given EpochStats.
    /// - parameter epochStats: Statistics of epoch considered for the song.
    /// - returns: Promise that will be resolved with the song to play next.
    public static func getSong(for epochStats: EpochStats, with previousSong: Song) -> Promise<Song> {
        let (promise, resolver) = Promise<Song>.pending()
        let endpointURL = backendBaseURL.appendingPathComponent("/nextSong")
        let songRequestParameter = SongRequest(
            epochStats: epochStats,
            previousSong: previousSong
        )
        
        self.cache.fetch(key: songRequestParameter.cacheKey).onSuccess { cachedSong in
            resolver.fulfill(cachedSong)
        }.onFailure { error in
            _ = Alamofire.request(
                endpointURL,
                method: .get,
                parameters: songRequestParameter.parameters
            ).responseJSON().done { data in
                print(data)
                let url = "http://google.com"
                let name = "Google"
                
                let song = Song(spotifyURI: url, name: name)
                
                resolver.fulfill(song)
            }
        }
        
        return promise
    }
    
}
