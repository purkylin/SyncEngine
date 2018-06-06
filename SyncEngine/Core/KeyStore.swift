//
//  KeyStore.swift
//  Engine
//
//  Created by Purkylin King on 2018/6/5.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import RealmSwift

class KeyStoreModel: Object {
    @objc dynamic var key: String = ""
    @objc dynamic var value: Data = Data()
    
    override static func primaryKey() -> String? {
        return "key"
    }
    
    override static func indexedProperties() -> [String] {
        return ["key"]
    }
}

class KeyStore {
    static let shared = KeyStore()
    
    subscript(key: String) -> Data? {
        get {
            let realm = try! Realm()
            return realm.object(ofType: KeyStoreModel.self, forPrimaryKey: key)?.value
        }
        set {
            let realm = try! Realm()
            if let obj = realm.object(ofType: KeyStoreModel.self, forPrimaryKey: key) {
                try! realm.write {
                    if newValue == nil {
                        realm.delete(obj)
                    } else {
                        obj.value = newValue!
                    }
                }
            } else {
                if newValue != nil {
                    let newObj = KeyStoreModel()
                    newObj.key = key
                    newObj.value = newValue!
                    
                    try! realm.write {
                        realm.add(newObj)
                    }
                }
            }
        }
    }
}
