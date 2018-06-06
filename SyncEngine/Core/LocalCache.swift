//
//  LocalCache.swift
//  Engine
//
//  Created by Purkylin King on 2018/6/6.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import CloudKit

extension Notification.Name {
    static let zoneCacheDidChange = Notification.Name("zoneCacheDidChange")
    static let topicCacheDidChange = Notification.Name("objectCacheDidChange")
    static let zoneDidSwitch = Notification.Name("zoneDidSwtich")
}

struct ZoneCacheChanges {
    private(set) var database: Database
    private(set) var zoneIDsDeleted = [CKRecordZoneID]()
    private(set) var zoneIDsChanged = [CKRecordZoneID]()
}

struct ObjectCacheChanges {
    private(set) var recordIDsDeleted = [CKRecordID]()
    private(set) var recordsChanged = [CKRecord]()
}

class NotificationObject<T> {
    var payload: T?
    
    init(payload: T? = nil) {
        self.payload = payload
    }
}

typealias ZoneCacheDidChange = NotificationObject<ZoneCacheChanges>
typealias ObjectCacheDidChange = NotificationObject<ObjectCacheChanges>
