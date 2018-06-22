//
//  CKError+Detail.swift
//  SyncEngine
//
//  Created by Purkylin King on 2018/6/22.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import CloudKit

extension CKError {
    public func isSpecificErrorCode(code: CKError.Code) -> Bool {
        var match = false
        if self.code == code {
            match = true
        }
        else if self.code == .partialFailure {
            // This is a multiple-issue error. Check the underlying array
            // of errors to see if it contains a match for the error in question.
            guard let errors = partialErrorsByItemID else {
                return false
            }
            for (_, error) in errors {
                if let cke = error as? CKError {
                    if cke.code == code {
                        match = true
                        break
                    }
                }
            }
        }
        return match
    }
    
    public func isRecordNotFound() -> Bool {
        return isSpecificErrorCode(code: .unknownItem)
    }
    
    public func isWriteFailure() -> Bool {
        return isSpecificErrorCode(code: .permissionFailure)
    }
}
