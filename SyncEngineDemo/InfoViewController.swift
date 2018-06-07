//
//  InfoViewController.swift
//  SyncEngineDemo
//
//  Created by Purkylin King on 2018/6/7.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import UIKit
import SyncEngine
import CloudKit

class InfoViewController: UIViewController {
    var note: Note!

    @IBOutlet weak var createrLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var deviceLabel: UILabel!
    @IBOutlet weak var modifyDateLabel: UILabel!
    @IBOutlet weak var modifierLabel: UILabel!
    @IBOutlet weak var readWriteLabel: UILabel!
    
    let formatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
        countLabel.text =  "\(note.title.count)"
        
        
        let record = note.syncRecord
//        var share: CKShare? = nil
        deviceLabel.text = record["modifiedByDevice"] as? String
        
        if note.shared {
            if let share = record.sharedRecord() {
                readWriteLabel.text =  share.publicPermission == .readWrite ? "true" : "false"
            }
            
            
        } else {
            readWriteLabel.text = "true"
            createrLabel.text = "owner"
        }
        
        modifyDateLabel.text = toString(date: record.modificationDate)
    }
    
    func toString(date: Date?) -> String {
        guard date != nil else { return "" }
        return formatter.string(from: date!)
    }


}
