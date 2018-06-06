# SyncEngine
Sync between iCloud and Realm

## Feature

- [x] Sync betweens different device
- [x] Share
- [x] Offline
- [x] Resolve conflict
- [x] Multi table
- [ ] CKAsset
- [ ] Stable API
- [ ] Documentation
- [ ] Same device different iCloud account
- [ ] Background long task

## Usage
1. model
```swift
@objc(SimpleNote)
class SimpleNote: SyncBaseModel {
    @objc dynamic var title: String = ""
}
```

2. AppDelegate
```swift
application.registerForRemoteNotifications()

syncEngine.register(models: [SimpleNote.self])
syncEngine.start()
```

3. Sync
```
syncEngine.sync()
```

## Carthage
`github "purkylin/SyncEngine"`
