//
//  Note.swift
//  SyncEngineDemo
//
//  Created by Purkylin King on 2018/6/7.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import SyncEngine

@objc(Note)
class Note: SyncBaseModel {
    @objc dynamic var title: String = ""
}
