//
//  ViewController.swift
//  SyncEngineDemo
//
//  Created by Purkylin King on 2018/6/7.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import UIKit
import RealmSwift
import SyncEngine

class ViewController: UIViewController {
    var notes: Results<Note>!
    var notificationToken: NotificationToken? = nil
    
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    func setup() {
        let realm = try! Realm()
        notes = realm.objects(Note.self).filter("deleted == false")
        
        notificationToken = notes.observe({ [weak self] (changs: RealmCollectionChange) in
            guard let tableView = self?.tableView else { return }
            
            switch changs {
            case .initial:
                tableView.reloadData()
            case .update(_, let deletions, let insertions, let modifications):
                // select
                tableView.beginUpdates()
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0)}), with: .automatic)
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}), with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0)}), with: .automatic)
                tableView.endUpdates()
            case .error(let error):
                fatalError("\(error)")
            }
        })
    }
    
    @IBAction func btnSyncClicked(_ sender: Any) {
        SyncEngine.default.sync()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "detail" {
            guard let indexPath = tableView.indexPathForSelectedRow else { return }
            let vc = segue.destination as? EditViewController
            vc?.note = notes[indexPath.row]
        } else { // add
            // do nothing
        }
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = notes[indexPath.row].title
        return cell
    }
}

