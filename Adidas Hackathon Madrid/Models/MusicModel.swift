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
//private let backendBaseURL: URL = URL(string: "http://52.31.62.57")!
private let backendBaseURL: URL = URL(string: "http://10.0.3.23:3000")!

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
public class Song: NSObject, NSCoding, DataRepresentable, DataConvertible {
    /// URI of this song in Spotify.
    public let spotifyURI: String
    /// Name of this song.
    public let name: String
    /// URL to album artwork.
    public let artworkURL: String
    /// Song request which produced this song.
    public let request: SongRequest?
    
    public init(spotifyURI: String, name: String, artworkURL: String, request: SongRequest? = nil) {
        self.spotifyURI = spotifyURI
        self.name = name
        self.artworkURL = artworkURL
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
            request: request
        )
    }
    
    // MARK: - First Song
    
    /// Initial song of a running session.
    public static var initialSong: Song {
        get {
            return Song(
                spotifyURI: "spotify:track:1bdXMstfxFWYSkEFTnJMoN",
                name: "Enter Sandman",
                artworkURL: "https://i.scdn.co/image/1e886ca74a1dc17b9a226283b9cc4b765ee25cb8"
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
    
    // MARK: - NSCoding Protocol Methods
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.spotifyURI, forKey: Song.spotifyURIKey)
        aCoder.encode(self.name, forKey: Song.nameKey)
        aCoder.encode(self.artworkURL, forKey: Song.artworkURLKey)
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard
            let spotifyURI = aDecoder.decodeObject(forKey: Song.spotifyURIKey) as? String,
            let name = aDecoder.decodeObject(forKey: Song.nameKey) as? String,
            let artworkURL = aDecoder.decodeObject(forKey: Song.artworkURLKey) as? String
        else {
            return nil
        }
        
        self.init(spotifyURI: spotifyURI, name: name, artworkURL: artworkURL)
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
    
    /// Next song to be played.
    private static var nextSong: Song? = nil
    
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
        return player
    }()
    
    /// View controller used to authenticate in Spotify.
    private static let spotifyAuthenticationViewController: UIViewController = {
        let authURL: URL = MusicModel.auth.spotifyWebAuthenticationURL()
        let authViewController = SFSafariViewController(url: authURL)
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
            try self.player.start(withClientId: self.auth.clientID)
            self.player.login(withAccessToken: self.auth.session.accessToken)
            self.player.delegate = UIApplication.shared.delegate as? AppDelegate
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
            
            do {
                try self.player.start(withClientId: self.auth.clientID)
                self.player.login(withAccessToken: session.accessToken)
                self.player.delegate = UIApplication.shared.delegate as? AppDelegate
                resolver.fulfill(())
            } catch let error {
                return resolver.reject(error)
            }
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
    public static func playNext() -> Promise<Void> {
        guard let song = self.nextSong else {
            return Promise<Void>(error: MusicModelError.noNextSongAvailable)
        }
        return self.replaceCurrentlyPlayingSong(with: song)
    }
    
    /// Replaces next song in the queue with given song.
    public static func replaceEnqueuedSong (with newSong: Song) {
        self.nextSong = newSong
    }
    
    /// Replaces currently playing song with given one.
    public static func replaceCurrentlyPlayingSong (with newSong: Song) -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()
        
        print(newSong.spotifyURI)
        
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
            resolver.fulfill(())
        }
        
        return promise
    }
    
    /// Remaining duration in seconds of currently playing song.
    /// Will be `nil` if currently nothing is being played.
    public static var currentlyPlayedSongRemainingDuration: TimeInterval? {
        get {
            guard self.player.metadata.currentTrack != nil else {
                return nil
            }
            return self.player.playbackState.position
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
            return self.player.playbackState.position / duration
        }
    }
    
    // MARK: - Backend API
    
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
            resolver.fulfill(cachedSong.with(request: songRequestParameter))
        }.onFailure { error in
            _ = Alamofire.request(
                endpointURL,
                method: .get,
                parameters: songRequestParameter.parameters
            ).responseJSON().done { data in
                guard
                    let json = data.json as? NSDictionary,
                    let uri = json.value(forKey: "SpotifyUrl") as? String,
                    let name = json.value(forKey: "Name") as? String,
                    let artworkURL = json.value(forKey: "ImageUrlL") as? String
                else {
                    return resolver.reject(MusicModelError.unparseableBackendResponse)
                }
        
                let song = Song(
                    spotifyURI: uri,
                    name: name,
                    artworkURL: artworkURL,
                    request: songRequestParameter
                )
                
                self.cache.set(value: song, key: songRequestParameter.cacheKey)
                
                resolver.fulfill(song)
            }
        }
        
        return promise
    }
    
}
