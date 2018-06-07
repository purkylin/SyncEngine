//
//  SyncEngine.swift
//  Engine
//
//  Created by Purkylin King on 2018/6/5.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import CloudKit
import RealmSwift

internal let customZoneName = "kingprivatezone"

public final class SyncEngine {
    public static let `default` = SyncEngine()
    let container = CKContainer.default()
    let databases: [Database]
    
    internal var models = [SyncBaseModel.Type]()
    
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    
    private lazy var cacheQueue: DispatchQueue = {
        return DispatchQueue(label: "LocalCache", attributes: .concurrent)
    }()
    
    func performWriterBlock(_ writerBlock: @escaping () -> Void) {
        cacheQueue.async(flags: .barrier) {
            writerBlock()
        }
    }
    
    // Register sync model
    public func register(models: [SyncBaseModel.Type]) {
        assert(models.count > 0)
        self.models = models
    }
    
    public func sync() {
        assert(models.count > 0, "Error You havn't register any model")
        databases.forEach { $0.syncLocalChanges() }
    }
    
    public func start() {
        // Add item CKSharingSupported in your Info.plist if you use share
        
        for database in databases {
            if UserDefaults.standard.bool(forKey: DefaultsKey.subscriptionSaveKey) {
                fetchChanges(from: database)
                continue
            }
            
            database.cloudKitDB.addDatabaseSubscription(subscriptionID: database.cloudKitDB.name, operationQueue: operationQueue) { error in
                guard handleCloudKitError(error, operation: .modifySubscriptions) == nil else { return }
                UserDefaults.standard.set(true, forKey: DefaultsKey.subscriptionSaveKey)
                self.fetchChanges(from: database)
            }
        }
    }
    
    public func didReceiveRemoteNotification(userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let appState = UIApplication.shared.applicationState
        guard let userInfo = userInfo as? [String: NSObject],
            appState != .inactive else { return }
        
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard let subscriptionID = notification.subscriptionID else { return }
        if notification.notificationType == .database {
            for database in SyncEngine.default.databases {
                if database.cloudKitDB.name == subscriptionID {
                    SyncEngine.default.fetchChanges(from: database)
                    break
                }
                
            }
        }
        completionHandler(.noData)
    }
    
    // Post the notification after all the operations are done so that observers can update the UI
    // This method can be tr-entried
    //
    func postWhenOperationQueueClear(name: NSNotification.Name, object: Any? = nil) {
        
        DispatchQueue.global().async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: name, object: object)
            }
        }
    }
    
    init() {
        databases = [
            Database(cloudKitDB: container.privateCloudDatabase),
            Database(cloudKitDB: container.sharedCloudDatabase)
        ]
        
        addZone(with: customZoneName, to: databases[0])
        
        NotificationCenter.default.addObserver(self, selector: #selector(zoneCacheDidChange(_:)), name: .zoneCacheDidChange, object: nil)
    }
    
    func fetchChanges(from database: Database) {
        var zoneIDsChanged = [CKRecordZoneID](), zoneIDsDeleted = [CKRecordZoneID]()
        let changeToken = database.serverChangeToken
        
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
        let notificationObject = ZoneCacheDidChange()

        operation.changeTokenUpdatedBlock = { changeToken in
            self.performWriterBlock {
                database.save(changeToken: changeToken)
            }
        }
        
        operation.recordZoneWithIDWasDeletedBlock = { zoneID in
            zoneIDsDeleted.append(zoneID)
        }
        
        operation.recordZoneWithIDChangedBlock = { zoneID in
            zoneIDsChanged.append(zoneID)
        }
        
        operation.fetchDatabaseChangesCompletionBlock = { changeToken, more, error in
            if let ckError = handleCloudKitError(error, operation: .fetchChanges, alert: true),
                ckError.code == .changeTokenExpired {
                
                self.performWriterBlock { database.save(changeToken: nil) }
                self.fetchChanges(from: database) // Fetch changes again with nil token.
                return
            }
            
            self.performWriterBlock { database.save(changeToken: changeToken) }
            
            // filter deletedID
            zoneIDsChanged = zoneIDsChanged.filter { zoneID in return !zoneIDsDeleted.contains(zoneID) }
            
            notificationObject.payload = ZoneCacheChanges(
                database: database, zoneIDsDeleted: zoneIDsDeleted, zoneIDsChanged: zoneIDsChanged)
            
            // fetch zone
        }
        
        operation.database = database.cloudKitDB
        operationQueue.addOperation(operation)
        postWhenOperationQueueClear(name: .zoneCacheDidChange, object: notificationObject)
    }
    
    // MARK: - Modify zones
    
    func addZone(with zoneName: String, to database: Database) {
        if UserDefaults.standard.bool(forKey: DefaultsKey.createCustomeZone) {
            return
        }
        
        let zoneID = CKRecordZoneID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let newZone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [newZone], recordZoneIDsToDelete: nil)
        operation.modifyRecordZonesCompletionBlock = { zones, zoneIDs, error in
            guard handleCloudKitError(error, operation: .modifyZones, alert: true) == nil,
                let savedZone = zones?[0] else { return }
            self.performWriterBlock {
                database.zones.append(savedZone)
                UserDefaults.standard.setValue(true, forKey: DefaultsKey.createCustomeZone)
            }
        }
        
        operation.database = database.cloudKitDB
        operationQueue.addOperation(operation)
    }
    
    func deleteZone(_ zone: CKRecordZone, from database: Database) {
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [zone.zoneID])
        operation.modifyRecordZonesCompletionBlock = { (_, _, error) in
            
            guard handleCloudKitError(error, operation: .modifyRecords, alert: true) == nil else { return }
            
            self.performWriterBlock {
                if let index = database.zones.index(of: zone) {
                    database.zones.remove(at: index)
                }
            }
        }
        operation.database = database.cloudKitDB
        operationQueue.addOperation(operation)
    }
    
    // MARK: - Notification
    
    @objc func zoneCacheDidChange(_ notification: Notification) {
        guard let zoneChanges = (notification.object as? ZoneCacheDidChange)?.payload else { return }
        zoneChanges.database.fetchZoneChanges(zoneIDs: zoneChanges.zoneIDsChanged)
        // TODO: Delete zone
        
    }
    
    // MARK: - Others
    
    public func userDidAcceptCloudKitShare(with metadata: CKShareMetadata) {
        let acceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        acceptSharesOperation.acceptSharesCompletionBlock = { error in
            guard handleCloudKitError(error, operation: .acceptShare, alert: true) == nil else { return }
            // TODO: Fetch
            print("access success")
        }
        container.add(acceptSharesOperation)
    }
    
    public func saveShare(record: CKRecord, completion:@escaping (CKShare?, Error?) -> Void) {
        var share: CKShare?
        if let shareID = record.share?.recordID {
            share = KeyStore.shared.record(id: shareID.recordName) as? CKShare
        }
        
        if share == nil {
            share = CKShare(rootRecord: record)
        }
        
        let modifyRecordsOperation = CKModifyRecordsOperation(
            recordsToSave: [record, share!],
            recordIDsToDelete: nil)
        
        modifyRecordsOperation.timeoutIntervalForRequest = 10
        modifyRecordsOperation.timeoutIntervalForResource = 10
        
        modifyRecordsOperation.modifyRecordsCompletionBlock =
            { records, recordIDs, error in
                if error != nil {
                    print(error!.localizedDescription)
                } else {
                    print("save share success")
                }
                
                completion(share, error)
        }
        
        container.privateCloudDatabase.add(modifyRecordsOperation)
    }
    
//    public func addParty(email: String, to record: CKRecord) {
//        var share: CKShare?
//        if let shareID = record.share?.recordID {
//            share = KeyStore.shared.record(id: shareID.recordName) as? CKShare
//        }
//        
//        if share == nil {
//            share = CKShare(rootRecord: record)
//        }
//        
//        let participant = CKShareParticipant(coder: email)
//    }

}
