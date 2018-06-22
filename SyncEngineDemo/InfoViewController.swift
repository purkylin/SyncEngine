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

struct Platform {
    static var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }
}

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
        
        let item = UIBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(btnShareClicked))
        self.navigationItem.rightBarButtonItem = item
        
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
    
    func showAddShare() {
        let vc = UICloudSharingController { (controller, completion) in
            SyncEngine.default.saveShare(record: self.note.syncRecord, completion: { (share, error) in
                //                guard let share = share, error == nil else { return }
                completion(share, CKContainer.default(), error)
            })
        }
        
        vc.popoverPresentationController?.sourceView = self.view
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }

    @objc func btnShareClicked() {
        if let recordID = note.syncRecord.share?.recordID {
            SyncEngine.default.fetchShare(recordID: recordID, isOwner: note.syncRecord.isOwner) { (share, error) in
                if let error = error as? CKError {
                    if error.isRecordNotFound() {
                        self.showAddShare()
                    } else {
                        print(error.localizedDescription)
                    }
                    return
                }
 
                guard error == nil else { return }
                let vc = UICloudSharingController(share: share!, container: CKContainer.default())
                vc.popoverPresentationController?.sourceView = self.view
                self.present(vc, animated: true, completion: nil)
                vc.delegate = self
            }
        } else {
            showAddShare()
        }
    }
}

extension InfoViewController: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Error: share")
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "Hello Share"
    }
    
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        if Platform.isSimulator {
            SyncEngine.default.fetchChanges()
        }
        print("share success")
    }
}
