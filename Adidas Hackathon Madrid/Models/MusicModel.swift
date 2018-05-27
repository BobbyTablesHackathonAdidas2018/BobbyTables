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
                "song": self.previousSong.name,
                "artist": self.previousSong.artistName
            ]
        }
    }
    
    /// Returns a key for caching this request.
    public var cacheKey: String {
        get {
            return String(format: "song::%@::--bpm--::%.0f", self.previousSong.name, self.epochStats.bpm)
        }
    }
}

/// Data structure holding metadata of a Spotify song.
public class Song: NSObject, NSCoding, DataRepresentable, DataConvertible {
    /// URI of this song in Spotify.
    public let spotifyURI: String
    /// Name of this song.
    public let name: String
    /// URL to album artwork.
    public let artworkURL: String
    /// Name of the artist.
    public let artistName: String
    /// Song request which produced this song.
    public let request: SongRequest?
    
    public init(
        spotifyURI: String,
        name: String,
        artworkURL: String,
        artistName: String,
        request: SongRequest? = nil
    ) {
        self.spotifyURI = spotifyURI
        self.name = name
        self.artworkURL = artworkURL
        self.artistName = artistName
        self.request = request
    }
    
    /// Returns a new Song with given request as song request which produced it.
    /// - note: Specially useful when reading from cache.
    /// - parameter request: New song request.
    /// - returns: Properly initialized Song.
    fileprivate func with(request: SongRequest) -> Song {
        return Song(
            spotifyURI: self.spotifyURI,
            name: self.name,
            artworkURL: self.artworkURL,
            artistName: self.artistName,
            request: request
        )
    }
    
    // MARK: - First Song
    
    /// Initial song of a running session.
    public static var initialSong: Song {
        get {
            return Song(
                spotifyURI: "spotify:track:0nj2MZ1FKbgxTHxdLuK66S",
                name: "I Wanna Take You Out",
                artworkURL: "https://i.scdn.co/image/c0fa3ee6f34b20d536e890a74bd97a136443f629",
                artistName: "CMD/CTRL"
            )
        }
    }
    
    // MARK: -
    
    /// Key used to encode `spotifyURI` attribute in NSCoder.
    private static let spotifyURIKey: String = "spotifyURI"
    /// Key used to encode `name` attribute in NSCoder.
    private static let nameKey: String = "name"
    /// Key used to encode `artworkURL` attribute in NSCoder.
    private static let artworkURLKey: String = "artworkURL"
    /// Key used to encode `artistName` attribute in NSCoder.
    private static let artistNameKey: String = "artistName"
    
    // MARK: - NSCoding Protocol Methods
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.spotifyURI, forKey: Song.spotifyURIKey)
        aCoder.encode(self.name, forKey: Song.nameKey)
        aCoder.encode(self.artworkURL, forKey: Song.artworkURLKey)
        aCoder.encode(self.artistName, forKey: Song.artistNameKey)
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard
            let spotifyURI = aDecoder.decodeObject(forKey: Song.spotifyURIKey) as? String,
            let name = aDecoder.decodeObject(forKey: Song.nameKey) as? String,
            let artworkURL = aDecoder.decodeObject(forKey: Song.artworkURLKey) as? String,
            let artistName = aDecoder.decodeObject(forKey: Song.artistNameKey) as? String
        else {
            return nil
        }
        
        self.init(
            spotifyURI: spotifyURI,
            name: name,
            artworkURL: artworkURL,
            artistName: artistName
        )
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
    
    /// Requests that have been already inited and should not be retried.
    private static var initiedRequests: [String: Promise<Song>] = [:]
    
    /// Next song to be played.
    private static var nextSong: Song = Song.initialSong
    
    /// Whether there's a next song enqueued (`true`) or not.
    public static var hasNextSong: Bool {
        return self.nextSong.spotifyURI != MusicModel.currentlyPlayingSong?.spotifyURI ?? Song.initialSong.spotifyURI
    }
    
    /// Last date when song was updated.
    private static var lastSongUpdateTime: Date = Date()
    
    /// Currently played song.
    public static var currentlyPlayingSong: Song? = nil
    
    // MARK: - Spotify
    
    /// Spotify API authentication.
    private static let auth: SPTAuth = {
        let auth: SPTAuth! = SPTAuth.defaultInstance()
        // The client ID you got from the developer site
        auth.clientID = "b0be0eab16704e728a7c7bf90ff8806e"
        // The redirect URL as you entered it at the developer site
        auth.redirectURL = URL(string: "bobbytables://login-success")
        // Setting the `sessionUserDefaultsKey` enables SPTAuth to automatically store the session object for future use.
        auth.sessionUserDefaultsKey = "current session"
        // Set the scopes you need the user to authorize. `SPTAuthStreamingScope` is required for playing audio.
        auth.requestedScopes = [SPTAuthStreamingScope]
        return auth
    }()
    
    /// Spotify player.
    private static let player: SPTAudioStreamingController = {
        let player: SPTAudioStreamingController! = SPTAudioStreamingController.sharedInstance()
        player.delegate = UIApplication.shared.delegate as! AppDelegate
        try! player.start(withClientId: MusicModel.auth.clientID)
        player.delegate = UIApplication.shared.delegate as? AppDelegate
        return player
    }()
    
    /// View controller used to authenticate in Spotify.
    private static let spotifyAuthenticationViewController: UIViewController = {
        let authURL: URL = MusicModel.auth.spotifyWebAuthenticationURL()
        let authViewController = SFSafariViewController(url: authURL)
        authViewController.preferredBarTintColor = UIColor.ezbeatGreen
        authViewController.preferredControlTintColor = UIColor.white
        return authViewController
    }()
    
    /// Promise returned when started a Spotify Authentication flow which
    /// required explicit user login and resolver linked to that promise.
    private static let (
        spotifyAuthenticationFlowPromise,
        spotifyAuthenticationFlowResolver
    ) = Promise<Void>.pending()
    
    // MARK: - Spotify API helpers
    
    /// Starts Spotify authentication flow, if required.
    /// - parameter presentViewController: Block used to present authentication
    /// view controller when required.
    /// - returns: Promise that is resolved with no value after authentication
    /// flow finishes.
    public static func startSpotifyAuthenticationFlow (
        presentViewController: @escaping (UIViewController) -> Void
    ) -> Promise<Void> {
        // If we don't have an access token then we have to log in...
        guard let session = self.auth.session, session.isValid() else {
            presentViewController(self.spotifyAuthenticationViewController)
            return self.spotifyAuthenticationFlowPromise
        }
        
        return Promise<Void>() { resolver in
            // Otherwise we can just use it...
            self.player.login(withAccessToken: self.auth.session.accessToken)
            resolver.fulfill(())
        }
    }
    
    /// Handles Spotify authentication callback URL, setting app audio player.
    /// - throws: Error if the URL cannot be handled.
    /// - parameter url: URL to be handled.
    /// - returns: Promise that will be resolved with no value on success.
    public static func handleAuthenticationCallback(_ url: URL) throws -> Promise<Void> {
        guard self.auth.canHandle(url) else {
            throw MusicModelError.unhandlableAuthenticationCallbackURL
        }
        
        // Close the authentication window
        self.spotifyAuthenticationViewController.presentingViewController?.dismiss(
            animated: true,
            completion: nil
        )
        
        let (promise, resolver) = Promise<Void>.pending()
        
        // Parse the incoming url to a session object...
        self.auth.handleAuthCallback(withTriggeredAuthURL: url) { (optionalError, optionalSession) in
            if let error = optionalError {
                return resolver.reject(error)
            }
            
            guard let session = optionalSession else {
                return resolver.reject(MusicModelError.unexpectedSpotifySessionValidation)
            }
            
            self.player.login(withAccessToken: session.accessToken)
            resolver.fulfill(())
        }
        
        _ = promise.done {
            self.spotifyAuthenticationFlowResolver.fulfill(())
        }.catch { error in
            self.spotifyAuthenticationFlowResolver.reject(error)
        }
        
        return promise
    }
    
    // MARK: - Public Playback API
    
    /// Stops playing current song and starts playing next one.
    public static func playNext() -> Promise<Song> {
        return self.replaceCurrentlyPlayingSong(with: self.nextSong)
    }
    
    /// Replaces next song in the queue with given song.
    public static func replaceEnqueuedSong (with newSong: Song) {
        self.nextSong = newSong
    }
    
    /// Replaces currently playing song with given one.
    public static func replaceCurrentlyPlayingSong (with newSong: Song) -> Promise<Song> {
        let (promise, resolver) = Promise<Song>.pending()
        
        print(newSong.spotifyURI)
        
        guard
            self.currentlyPlayingSong == nil ||
            Date().timeIntervalSince(self.lastSongUpdateTime) > 5
        else {
            print("NOT UPDATING SONG BECAUSE WE UPDATED IT TOO SOON!")
            return Promise<Song>(error: MusicModelError.askedToPlayTooSoon)
        }
        
        self.lastSongUpdateTime = Date()
        
        self.player.playSpotifyURI(
            newSong.spotifyURI,
            startingWith: 0,
            startingWithPosition: 0
        ) { optionalError in
            if let error = optionalError {
                print(error.localizedDescription)
                return resolver.reject(error)
            }
            self.currentlyPlayingSong = newSong
            resolver.fulfill(newSong)
        }
        
        return promise
    }
    
    /// Remaining duration in seconds of currently playing song.
    /// Will be `nil` if currently nothing is being played.
    public static var currentlyPlayedSongRemainingDuration: TimeInterval? {
        get {
            guard
                let duration = self.player.metadata.currentTrack?.duration,
                duration > 0
            else {
                return nil
            }
            return duration - self.player.playbackState.position
        }
    }
    
    /// Remaining duration in seconds of currently playing song in percentage
    /// with respect to total duration of the song.
    /// Will be `nil` if currently nothing is being played.
    public static var currentlyPlayedSongRemainingPercent: Double? {
        get {
            guard
                let duration = self.player.metadata.currentTrack?.duration,
                duration > 0
            else {
                return nil
            }
            return 1 - self.player.playbackState.position / duration
        }
    }
    
    // MARK: - Backend API
    
    /// Gets the proper song for given EpochStats.
    /// - parameter epochStats: Statistics of epoch considered for the song.
    /// - returns: Promise that will be resolved with the song to play next.
    public static func getSong(
        for epochStats: EpochStats,
        with previousSong: Song
    ) -> Promise<Song> {
        guard epochStats.bpm > 0 else {
            return Promise<Song>.value(Song.initialSong)
        }
        
        let endpointURL = backendBaseURL.appendingPathComponent("/nextSong")
        let songRequestParameter = SongRequest(
            epochStats: epochStats,
            previousSong: previousSong
        )
        
        if let promise = self.initiedRequests[songRequestParameter.cacheKey] {
            return promise
        }
        
        let (promise, resolver) = Promise<Song>.pending()
        
        self.initiedRequests[songRequestParameter.cacheKey] = promise
        
        print("Querying for \(epochStats.bpm) and \(previousSong.artistName)")
        
        self.cache.fetch(key: songRequestParameter.cacheKey).onSuccess { cachedSong in
            resolver.fulfill(cachedSong.with(request: songRequestParameter))
        }.onFailure { error in
            _ = Alamofire.request(
                endpointURL,
                method: .get,
                parameters: songRequestParameter.parameters
            ).responseJSON().done { data in
                print("Got info!!")
                guard
                    let json = data.json as? NSDictionary,
                    let id = json.value(forKey: "Id") as? String,
                    let name = json.value(forKey: "Name") as? String,
                    let artworkURL = json.value(forKey: "ImageUrlL") as? String,
                    let artistName = json.value(forKey: "ArtistName") as? String
                else {
                    return resolver.reject(MusicModelError.unparseableBackendResponse)
                }
                
                let song = Song(
                    spotifyURI: String(format:"spotify:track:%@", id),
                    name: name,
                    artworkURL: artworkURL,
                    artistName: artistName,
                    request: songRequestParameter
                )
                
                self.cache.set(value: song, key: songRequestParameter.cacheKey)
                
                resolver.fulfill(song)
            }.catch { error in
                print(error)
                resolver.reject(error)
            }
        }
        
        return promise
    }
    
}
