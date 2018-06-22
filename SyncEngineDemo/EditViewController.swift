//
//  EditViewController.swift
//  SyncEngineDemo
//
//  Created by Purkylin King on 2018/6/7.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import UIKit
import RealmSwift

class EditViewController: UIViewController {
    var note: Note?
    
    @IBOutlet weak var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textField.text = note?.title ?? ""
    }

    @IBAction func btnSaveClicked(_ sender: Any) {
        if note == nil {
            note = Note()
        }
        
        let realm = try! Realm()
        try! realm.write {
            note!.title = textField.text ?? ""
            note?.synced = false
            note?.modifiedAt = Date()
            realm.add(note!)
        }
        
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func btnInfoclicked(_ sender: Any) {
        
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return note != nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as? InfoViewController
        vc?.note = note!
    }
}
