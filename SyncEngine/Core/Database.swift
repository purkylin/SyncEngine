//
//  Database.swift
//  Engine
//
//  Created by Purkylin King on 2018/6/5.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import CloudKit
import RealmSwift

class Database { // Wrap a CKDatabase, its change token, and its zones.
    var serverChangeToken: CKServerChangeToken?
    let cloudKitDB: CKDatabase
    var zones = [CKRecordZone]()
    let notificationObject = ObjectCacheDidChange()
    
    var isShared: Bool {
        return cloudKitDB.databaseScope == .shared
    }
    
    init(cloudKitDB: CKDatabase) {
        self.cloudKitDB = cloudKitDB
        self.serverChangeToken = readChangeToken()
    }
    
    private lazy var cacheQueue: DispatchQueue = {
        return DispatchQueue(label: "LocalCache", attributes: .concurrent)
    }()
    
    func performWriterBlock(_ writerBlock: @escaping () -> Void) {
        cacheQueue.async(flags: .barrier) {
            writerBlock()
        }
    }
    
    func addSubscription(to operationQueue: OperationQueue) {
        var key: String
        switch self.cloudKitDB.databaseScope {
        case .public:
            key = DefaultsKey.publicSubscriptionSaveKey
        case .private:
            key = DefaultsKey.privateSubscriptionSaveKey
        case .shared:
            key = DefaultsKey.sharedSubscriptionSaveKey
        }
        
        if UserDefaults.standard.bool(forKey: key) {
            return
        }
        
        cloudKitDB.addDatabaseSubscription(subscriptionID: cloudKitDB.name, operationQueue: operationQueue) { error in
            guard handleCloudKitError(error, operation: .modifySubscriptions) == nil else { return }
            UserDefaults.standard.set(true, forKey: key)
        }
    }
    
    // MARK: - Token
    public func readChangeToken() -> CKServerChangeToken? {
        let key = "ServerChangeToken-\(cloudKitDB.name)"
        return readToken(of: key)
    }
    
    public func save(changeToken: CKServerChangeToken?) {
        serverChangeToken = changeToken
        let key = "ServerChangeToken-\(cloudKitDB.name)"
        write(token: changeToken, key: key)
    }
    
    private func write(token: CKServerChangeToken?, key: String) {
        let defaults = UserDefaults.standard
        
        if token == nil {
            defaults.set(nil, forKey: key)
        } else {
            let data = NSKeyedArchiver.archivedData(withRootObject: token!)
            defaults.setValue(data, forKey: key)
        }
    }
    
    private func readToken(of key: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken
    }
    
    func save(zoneName: String, changeToken: CKServerChangeToken?) {
        let key = "ServerChangeToken-\(cloudKitDB.name)-zone-\(zoneName)"
        write(token: changeToken, key: key)
    }
    
    func readChangeToken(of zoneName: String) -> CKServerChangeToken? {
        let key = "ServerChangeToken-\(cloudKitDB.name)-zone-\(zoneName)"
        return readToken(of: key)
    }
    
    func generateOptions(zoneIDs: [CKRecordZoneID]) -> [CKRecordZoneID : CKFetchRecordZoneChangesOptions] {
        var result = [CKRecordZoneID : CKFetchRecordZoneChangesOptions]()
        for zoneID in zoneIDs {
            let options = CKFetchRecordZoneChangesOptions()
            options.previousServerChangeToken = readChangeToken(of: zoneID.zoneName)
            result[zoneID] = options
        }
        
        return result
    }
    
    // MARK: - Fetch
    
    func fetchZoneChanges(zoneIDs: [CKRecordZoneID]) {
        guard zoneIDs.count > 0 else { return }
        
        let options = generateOptions(zoneIDs: zoneIDs)
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: options)
        operation.fetchAllChanges = true
        
        var recordsChanged = [CKRecord]()
        var recordIDsDeleted = [CKRecordID]()
        
        operation.fetchRecordZoneChangesCompletionBlock = { error in
            if let ckError = handleCloudKitError(error, operation: .fetchChanges,
                                                 affectedObjects: nil) {
                print("Error in fetchRecordZoneChangesCompletionBlock: \(ckError)")
            }
            
            // The IDs in recordsChanged can be in recordIDsDeleted, meaning a changed record can be deleted,
            // So filter out the updated but deleted IDs.
            //
            recordsChanged = recordsChanged.filter { record in
                return !recordIDsDeleted.contains(record.recordID)
            }
            
            // Push recordIDsDeleted and recordsChanged into notification payload.
            //
            self.notificationObject.payload = ObjectCacheChanges(recordIDsDeleted: recordIDsDeleted,
                                                           recordsChanged: recordsChanged)
            
            self.performWriterBlock { // Do the update.
                self.updateWithRecordIDsDeleted(recordIDsDeleted)
                self.updateWithRecordsChanged(recordsChanged)
            }
            print("\(#function):Deleted \(recordIDsDeleted.count); Changed \(recordsChanged.count)")
        }
        
        operation.recordZoneFetchCompletionBlock = { zoneID, serverChangeToken, clientChangeTokenData, moreComing, error in
            if let ckError = handleCloudKitError(error, operation: .fetchChanges),
                ckError.code == .changeTokenExpired {
                self.performWriterBlock { self.save(zoneName: zoneID.zoneName, changeToken: nil) }
                self.fetchZoneChanges(zoneIDs: [zoneID])
                return
            }
            
            self.performWriterBlock { self.save(zoneName: zoneID.zoneName, changeToken: nil) }
        }
        
        operation.recordChangedBlock = { record in
            recordsChanged.append(record)
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            recordIDsDeleted.append(recordID)
        }
        
        operation.recordZoneChangeTokensUpdatedBlock = { zoneID, changeToken, _ in
            self.save(zoneName: zoneID.zoneName, changeToken: changeToken)
        }
        
        cloudKitDB.add(operation)
    }
    
    // MARK: - Modify
    
    func updateWithRecordIDsDeleted(_ recordIDs: [CKRecordID]) {
        guard recordIDs.count > 0 else { return }
        
        for recordID in recordIDs {
            deleteRecord(recordID: recordID)
        }
    }
    
    private func deleteRecord(recordID: CKRecordID) {
        let realm = try! Realm()
        var foundObj: SyncBaseModel?
        
        for model in SyncEngine.default.models {
            let obj = realm.objects(model).first { $0.id == recordID.recordName }
            if obj != nil {
                foundObj = obj
                break
            }
        }
        
        if let obj = foundObj {
            try! realm.write {
                realm.delete(obj)
            }
            
            KeyStore.shared[recordID.recordName] = nil
        }
    }
    
    func updateWithRecordsChanged(_ records: [CKRecord]) {
        guard records.count > 0 else { return }
        
        if self.cloudKitDB.databaseScope != .private {
            // Do something
        }

        for record in records {
            KeyStore.shared.save(record: record)

            if record.isKind(of: CKShare.self) {
                // TODO Readwrite
            } else {
                KeyStore.shared.save(record: record)
                let realm = try! Realm()
                // TODO: Compare
                let obj = SyncBaseModel.from(record: record)
                obj.synced = true
                obj.modifiedAt = Date()
                obj.ownerName = record.recordID.zoneID.ownerName
                
                try! realm.write {
                    realm.add(obj, update: true)
                }
            }
        }
    }
    
    // MARK: - Sync local changes
    func syncLocalChanges() {
        guard cloudKitDB.databaseScope != .public else { return }
        
        var toSaveRecords = [CKRecord]()
        var toDeleteRecordIDs = [CKRecordID]()
        
        let realm = try! Realm()
        
        for model in SyncEngine.default.models {
            let toSyncObjects = realm.objects(model).filter { obj in
                obj.synced == false && obj.shared == self.isShared
            }
            
            for object in toSyncObjects {
                let record = object.syncRecord
                if object.deleted {
                    toDeleteRecordIDs.append(record.recordID)
                } else {
                    toSaveRecords.append(record)
                }
            }
        }
        
        syncChanges(recordsToSave: toSaveRecords, recordIDsToDelete: toDeleteRecordIDs)
    }
    
    private func syncChanges(recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecordID]?) {
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
        operation.modifyRecordsCompletionBlock = { (saveRecords, deleteRecordIDs, error) in
            let failure = self.retryWhenPossible(with: error, block: {
                self.syncChanges(recordsToSave: saveRecords, recordIDsToDelete: deleteRecordIDs)
            })
            
            if failure == nil {
                self.performWriterBlock {
                    self.updateWithRecordsChanged(saveRecords ?? [])
                    self.updateWithRecordIDsDeleted(deleteRecordIDs ?? [])
                }
            } else {
                self.handleError(error: error!, completion: { (records, error) in
                    if error != nil {
                        print(error!.localizedDescription)
                        return
                    }
                    
                    if let count = records?.count, count > 0 {
                        self.syncChanges(recordsToSave: records, recordIDsToDelete: nil)
                    }
                })
            }
        }
        
        cloudKitDB.add(operation)
    }
    
    // MARK: - Resolve conflict
    
    private func retryWhenPossible(with error: Error?, block: @escaping () -> ()) -> Error? {
        guard let effectiveError = error as? CKError else {
            // not a CloudKit error or no error present, just return the original error
            return error
        }
        
        guard let retryAfter = effectiveError.retryAfterSeconds else {
            // CloudKit error, can't  be retried, return the error
            return effectiveError
        }
        
        // CloudKit operation can be retried, schedule `block` to be executed later
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryAfter) {
            block()
        }
        
        return nil
    }
    
    private func handleError(error: Error, completion: ([CKRecord]?, Error?) -> Void) {
        if let ckerror = error as? CKError {
            print(ckerror.localizedDescription)

            if ckerror.isWriteFailure() {
                completion(nil, error)
                return
            }
            
            switch ckerror.code {
            case .partialFailure:
                let adjustedRecords = resolveConflict(error: ckerror, resolver: overrideUseClient)
                completion(adjustedRecords, nil)
                return
            default:
                break
            }
        }
        
        completion(nil, error)
    }
    
    private func resolveConflict(error: CKError, resolver: (_ serverRecord: CKRecord, _ clientRecord: CKRecord, _ ancestorRecord: CKRecord) -> CKRecord) -> [CKRecord]? {
        guard let dict = error.partialErrorsByItemID else { return nil }
        
        var adjustRecords = [CKRecord]()
        
        for (_, itemError) in dict {
            if let ckerror = itemError as? CKError {
                switch ckerror.code {
                case .serverRecordChanged:
                    guard let serverRecord = ckerror.serverRecord,
                        let clientRecord = ckerror.clientRecord,
                        let ancestorRecord = ckerror.ancestorRecord else { return nil }
                    
                    if serverRecord.recordChangeTag != clientRecord.recordChangeTag {
                        let adjustRecord = resolver(serverRecord, clientRecord, ancestorRecord)
                        adjustRecords.append(adjustRecord)
                    } else {
                        print("conflict: save version")
                    }
                case .batchRequestFailed:
                    print("batch failed")
                // should retry
                default:
                    print("Not deal with other conflict")
                    print(ckerror.localizedDescription)
                    break
                }
            }
        }
        
        return adjustRecords
    }
    
    private func overrideUseClient(serverRecord: CKRecord, clientRecord: CKRecord, ancestorRecord: CKRecord) -> CKRecord {
        let adjustedRecord = serverRecord
        for key in clientRecord.allKeys() {
            adjustedRecord[key] = clientRecord[key]
        }
        return adjustedRecord
    }
}
