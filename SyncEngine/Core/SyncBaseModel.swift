//
//  SyncBaseModel.swift
//  Engine
//
//  Created by Purkylin King on 2018/6/3.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import RealmSwift
import CloudKit

extension CKRecord {
    func systemData() -> Data {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.requiresSecureCoding = true
        self.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return data as Data
    }
    
    static func recover(from data: Data) -> CKRecord? {
        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        unarchiver.requiresSecureCoding = true
        return CKRecord(coder: unarchiver)
    }
    
    public func sharedRecord() -> CKShare? {
        guard let id = share?.recordID.recordName else { return nil }
        return KeyStore.shared.record(id: id) as? CKShare
    }
}

extension KeyStore {
    func record(id: String) -> CKRecord? {
        guard let data = self[id], data.count > 0 else { return nil }
        return CKRecord.recover(from: data)
    }
    
    func save(record: CKRecord) {
        self[record.recordID.recordName] = record.systemData()
    }
}

open class SyncBaseModel: Object {
    @objc public dynamic var id = UUID().uuidString
    @objc public dynamic var createdAt = Date()
    @objc public dynamic var modifiedAt = Date()
    @objc public dynamic var deleted = false
    @objc public dynamic var synced = false
    
    @objc public dynamic var shared = false
    @objc public dynamic var readWrite = false
    
    static var recordType: String {
        return className()
    }
    
    var recordID: CKRecordID {
        let zoneID = CKRecordZoneID(zoneName: customZoneName, ownerName: CKCurrentUserDefaultName)
        return CKRecordID(recordName: id, zoneID: zoneID)
    }
    
    public var syncRecord: CKRecord {
        var record: CKRecord
        if let r = KeyStore.shared.record(id: id) {
            record = r
        } else {
            let typeName = type(of: self).recordType
            record = CKRecord(recordType: typeName, recordID: recordID)
            KeyStore.shared.save(record: record)
        }
        
        for property in self.objectSchema.properties {
            switch property.type {
            case .int, .string, .bool, .date, .float, .double:
                record[property.name] = self.value(forKey: property.name) as? CKRecordValue
            case .object:
                break
            default:
                print("Error: Unsupport property type")
                break
            }
        }
        
        return record
    }
    
    public static func from(record: CKRecord) -> SyncBaseModel {
        guard let modelClass = NSClassFromString(record.recordType) as? SyncBaseModel.Type else { return SyncBaseModel() }
        let model = modelClass.init()
        for property in model.objectSchema.properties {
            let key = property.name
            model.setValue(record[key], forKey: key)
        }
        return model
    }
    
    override open class func primaryKey() -> String? {
        return "id"
    }
}
