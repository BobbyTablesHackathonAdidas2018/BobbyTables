//
//  AppDelegate.swift
//  Adidas Hackathon Madrid
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 26/5/18.
//  Copyright © 2018 Bobby Tabbles. All rights reserved.
//


import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, SPTAudioStreamingDelegate {

    var window: UIWindow?
    var auth: SPTAuth!
    var player: SPTAudioStreamingController!
    var authViewController: UIViewController!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.auth = SPTAuth.defaultInstance()
        self.player = SPTAudioStreamingController.sharedInstance()
        // The client ID you got from the developer site
        self.auth.clientID = "b0be0eab16704e728a7c7bf90ff8806e"
        // The redirect URL as you entered it at the developer site
        self.auth.redirectURL = URL(string: "bobbytables://login-success")
        // Setting the `sessionUserDefaultsKey` enables SPTAuth to automatically store the session object for future use.
        self.auth.sessionUserDefaultsKey = "current session"
        // Set the scopes you need the user to authorize. `SPTAuthStreamingScope` is required for playing audio.
        self.auth.requestedScopes = [SPTAuthStreamingScope]

        // Become the streaming controller delegate
        self.player.delegate = self

        // Start up the streaming controller.
        
        do {
            try self.player.start(withClientId: self.auth.clientID)
        } catch (let e) {
          print("There was a problem starting the Spotify SDK: %@", e)
        
        }

        OperationQueue.main.addOperation {
          self.startAuthenticationFlow()
        }
    
        return true
    }

    func startAuthenticationFlow () {
        // Check if we could use the access token we already have
        guard let session = self.auth.session, session.isValid()
        else {
            // Get the URL to the Spotify authorization portal
            let authURL = self.auth.spotifyWebAuthenticationURL()
            // Present in a SafariViewController
            self.authViewController = SFSafariViewController(url: authURL!)
            self.window?.rootViewController?.present(self.authViewController, animated: true, completion: nil)
            return
        }
        // Use it to log in
        self.player.login(withAccessToken: self.auth.session.accessToken)
    
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

