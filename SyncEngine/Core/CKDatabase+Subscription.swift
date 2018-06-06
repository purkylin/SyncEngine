//
//  CKDatabase+Extension.swift
//  Engine
//
//  Created by Purkylin King on 2018/6/5.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import CloudKit

extension CKDatabase {
    
    var name: String { // Provide a display name for the database.
        switch databaseScope {
        case .public: return "Public"
        case .private: return "Private"
        case .shared: return "Shared"
        }
    }
        
    private func add(_ operation: CKDatabaseOperation, to queue: OperationQueue?) {
        if let operationQueue = queue {
            operation.database = self
            operationQueue.addOperation(operation)
        } else {
            add(operation)
        }
    }
    
    func addDatabaseSubscription(subscriptionID: String, operationQueue: OperationQueue?, completionHandler: @escaping ((Error?) -> Void)) {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKNotificationInfo()
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.modifySubscriptionsCompletionBlock = { _, _, error in
            completionHandler(error)
        }
        
        if let operationQueue = operationQueue {
            operation.database = self
            operationQueue.addOperation(operation)
        } else {
            add(operation)
        }
    }
   
}
