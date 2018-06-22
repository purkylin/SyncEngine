//
//  AppDelegate.swift
//  SyncEngineDemo
//
//  Created by Purkylin King on 2018/6/7.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import UIKit
import SyncEngine
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let engine = SyncEngine.default
        engine.register(models: [Note.self])
        engine.start()
        
        printPath()
        return true
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShareMetadata) {
        SyncEngine.default.userDidAcceptCloudKitShare(with: cloudKitShareMetadata)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        SyncEngine.default.didReceiveRemoteNotification(userInfo: userInfo, fetchCompletionHandler: completionHandler)
    }
    
    func printPath() {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        print("document path: \(path)")
    }
}

