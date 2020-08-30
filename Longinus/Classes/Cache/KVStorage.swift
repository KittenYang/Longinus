//
//  KVStorage.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/7/19.
//
//  Copyright (c) 2020 KittenYang <kittenyang@icloud.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
    

import Foundation
#if !USING_BUILTIN_SQLITE
import SQLite3
#endif


typealias KVStorageItemSample = (key: String, fileName: String?, size: Int32)

enum KVStorageValueType {
    case blob(data: Data)
    case text(string: String)
}

struct KVStorageItem : Equatable {
    var key: String
    var value: Data?
    var filename: String? // filename (nil if inline)
    
    var size = 0 // value's size in bytes
    var modTime = 0 // modification unix timestamp
    var accessTime = 0 //last access unix timestamp
}

func ==(lhs: KVStorageItem, rhs: KVStorageItem) -> Bool {
    return lhs.key == rhs.key && (lhs.value == rhs.value || lhs.filename == rhs.filename)
}

public enum KVStorageType {
    case file, sqlite, automatic
}

/**
 KVStorage is a key-value storage based on sqlite and file system.
Typically, you should not use this class directly.

 - Warining:
 The instance of this class is *NOT* thread safe, you need to make sure
 that there's only one thread to access the instance at the same time. If you really
 need to process large amounts of data in multi-thread, you should split the data
 to multiple KVStorage instance (sharding).
*/
class KVStorage<T: CustomStringConvertible & Hashable> {
    
    public let path: String
    public let type: KVStorageType
    fileprivate let db: KVStorageDatabase
    fileprivate let file: KVStorageFile
    var invalidated: Bool = false {
        didSet {
            db.invalidated =  invalidated
            file.invalidated = invalidated
        }
    }
    var totalItemSize: Int32 {
        return db.totalItemSize
    }
    
    var totalItemCount: Int32 {
        return db.totalItemCount
    }
    
    /**
     The designated initializer for KVStorage is `initWithPath:type:`.
     After initialized, a directory is created based on the `path` to hold key-value data.
     Once initialized you should not read or write this directory without the instance.
     */
    init?(path: String, type: KVStorageType) {
        self.path = path
        self.type = type
        let dbPath = (path as NSString).appendingPathComponent(KVStorageDatabase.Config.fileName)
        let dataPath = (path as NSString).appendingPathComponent("datas")
        let trashPath = (path as NSString).appendingPathComponent("trash")

        db = KVStorageDatabase(path: dbPath)
        file = KVStorageFile(dataPath: dataPath, trashPath: trashPath)

        let manager = FileManager.default

        try? manager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        try? manager.createDirectory(atPath: trashPath, withIntermediateDirectories: true, attributes: nil)
        try? manager.createDirectory(atPath: dataPath, withIntermediateDirectories: true, attributes: nil)

        
        if !db.open() || !db.initialize() {
            _ = db.close()
            reset()
            if !db.open() || !db.initialize() {
                _ = db.close()
                return nil
            }
        }
        file.emptyTrashInBackground()
        #if os(iOS)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(KVStorage.appWillBeTerminated(_:)),
                         name: UIApplication.willTerminateNotification,
                         object: nil)
        #endif

    }
    
    @objc fileprivate func appWillBeTerminated(_ sender: AnyObject?) {
        invalidated = true
    }
 
    deinit {
        _ = db.close()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Private
extension KVStorage {
    
    fileprivate func reset() {
        let manager = FileManager.default
        try? manager.removeItem(atPath: db.dbPath)
        try? manager.removeItem(atPath: (path as NSString).appendingPathComponent(KVStorageDatabase.Config.shmFileName))
        try? manager.removeItem(atPath: (path as NSString).appendingPathComponent(KVStorageDatabase.Config.walFileName))
        try? manager.removeItem(atPath: (path as NSString).appendingPathComponent(KVStorageDatabase.Config.lockFileName))

        _ = file.moveAllToTrash()
        file.emptyTrashInBackground()
    }
}

// MARK: - Operation
extension KVStorage {
    @discardableResult
    func save(item: KVStorageItem) -> Bool {
        return save(key: item.key, value: item.value, filename: item.filename)
    }
    
    @discardableResult
    func save(key: String, value: Data?) -> Bool {
        return save(key: key, value: value, filename: nil)
    }
    
    @discardableResult
    func save(key: String, value: Data?, filename: String?) -> Bool {
        guard let data = value, key.count > 0 else { return false}
        if type == .file && (filename?.isEmpty ?? true) { return false }
        
        if let name = filename {
            guard file.writeWithName(name, data: data),
                db.saveWithKey(key: key, value: data, fileName: name) else {
                    _ = file.deleteWithName(name)
                    return false
            }
            return true
        } else {
            if type != .sqlite {
                if let name = db.getFilenameWithKey(key: key) {
                    _ = file.deleteWithName(name)
                }
            }
            return db.saveWithKey(key: key, value: data, fileName: nil)
        }
    }
    
    @discardableResult
    func remove(forKey key: String) -> Bool {
        guard !key.isEmpty else {
            return false
        }
        switch type {
        case .sqlite:
            return db.deleteItemWithKey(key: key)
        case .automatic, .file:
            if let name = db.getFilenameWithKey(key: key) {
                _ = file.deleteWithName(name)
            }
            return db.deleteItemWithKey(key: key)
        }
    }
    
    @discardableResult
    func remove(forKeys keys: [String]) -> Bool {
        guard !keys.isEmpty else {
            return false
        }
        switch type {
        case .sqlite:
            return db.deleteItemsWithKeys(keys: keys)
        case .automatic, .file:
            let fileNames = db.getFilenamesWithKeys(keys: keys)
            fileNames?.forEach({ (name) in
                _ = file.deleteWithName(name)
            })
            return db.deleteItemsWithKeys(keys: keys)
        }
    }

    @discardableResult
    func remove(largerThan size: Int32) -> Bool {
        if size == Int32.max { return true }

        if size <= 0 { return remove(allItems: ()) }
        switch type {
        case .sqlite:
            if db.deleteItemsWithSizeLargerThan(size: size) {
                db.checkpoint()
                return true
            }
            return false
        case .automatic, .file:
            let names = db.getFilenamesWithSizeLargerThan(size: size)
            names?.forEach({ (name) in
                _ = file.deleteWithName(name)
            })
            if db.deleteItemsWithSizeLargerThan(size: size) {
                db.checkpoint()
                return true
            }
            return false
        }
    }
    
    @discardableResult
    func remove(earlierThan time: Int32) -> Bool {
        if time == Int32.max { return true }
        if time < 0 { return remove(allItems: ()) }
        switch type {
        case .sqlite:
            if db.deleteItemsWithTimeEarlierThan(time: time) {
                db.checkpoint()
                return true
            }
            return false
        case .automatic, .file:
            let names = db.getFilenamesWithTimeEarlierThan(time: time)
            names?.forEach({ (name) in
                _ = file.deleteWithName(name)
            })
            if db.deleteItemsWithTimeEarlierThan(time: time) {
                db.checkpoint()
                return true
            }
            return false
        }
    }
    
    @discardableResult
    func remove(toFitSize maxSize: Int32) -> Bool {
        if maxSize == Int32.max  { return true}
        if maxSize <= 0 { return remove(allItems: ())  }
        
        var total = db.totalItemSize
        if total < 0 { return false}
        if total <= maxSize { return true }
    
        var items = [KVStorageItemSample]()
        var success = false
        repeat {
            let perCount: Int32 = 16
            guard let temps = db.getItemSizeInfoOrderByTimeDescWithLimit(count: perCount) else { return false}
            items = temps
            for item in temps {
                if total > maxSize {
                    if let name = item.fileName {
                        _ = file.deleteWithName(name)
                    }
                    success = db.deleteItemWithKey(key: item.key)
                    total -= item.size
                } else {
                    break
                }
            }
            if !success { break }
        } while (total > maxSize && items.count > 0 && success)
        
        if success { db.checkpoint() }
        return success
    }
    
    @discardableResult
    func remove(toFitCount maxCount: Int32) -> Bool {
        if maxCount == Int32.max  { return true}
        if maxCount <= 0 { return remove(allItems: ())  }
        
        var total = db.totalItemCount
        if total < 0 { return false}
        if total <= maxCount { return true }

        var items = [KVStorageItemSample]()
        var success = false
        repeat {
            let perCount: Int32 = 16
            guard let temps = db.getItemSizeInfoOrderByTimeDescWithLimit(count: perCount) else { return false }
            items = temps
            for item in temps {
                if total > maxCount {
                    if let name = item.fileName {
                        _ = file.deleteWithName(name)
                    }
                    success = db.deleteItemWithKey(key: item.key)
                    total -= 1
                } else {
                    break
                }
            }
            if !success { break }
        } while (total > maxCount && items.count > 0 && success)
        
        if success { db.checkpoint() }
        return success
    }
    
    func remove(allItems progress: (_ removedCount: Int32, _ totalCount: Int32) -> Void,
                       finish: (_ error: Bool) -> Void) {
        let total = db.totalItemCount
        if total <= 0 {
            finish(total<0)
        } else {
            var left = total
            let perCount: Int32 = 32
            var items = [KVStorageItemSample]()
            var success = false
            repeat {
                guard let temps = db.getItemSizeInfoOrderByTimeDescWithLimit(count: perCount) else { break }
                items = temps
                for item in temps {
                    if left > 0 {
                        if let name = item.fileName {
                            _ = file.deleteWithName(name)
                        }
                        success = db.deleteItemWithKey(key: item.key)
                        left -= 1
                    } else {
                        break
                    }
                }
            } while(left < 0 && items.count > 0 && success)
            if success { db.checkpoint() }
            finish(!success)
        }
    }
    
    
    func itemForKey(key: String) -> KVStorageItem? {
        guard key.count > 0  else {
            return nil
        }
        guard var item = db.getItemWithKey(key: key, excludeInlineData: false) else { return nil }
        if let name = item.filename {
            item.value = file.readWithName(name)
            if item.value == nil {
                _ = db.deleteItemWithKey(key: key)
                return nil
            }
        }
        return item
    }
    
    func itemInfoForKey(key: String) -> KVStorageItem? {
        guard key.count > 0  else {
            return nil
        }
        return db.getItemWithKey(key: key, excludeInlineData: true)
    }
    
    func itemValueForKey(key: String) -> Data? {
        guard key.count > 0  else {
            return nil
        }
        var value: Data? = nil
        switch type {
        case .file:
            guard let name = db.getFilenameWithKey(key: key) else {
                return nil
            }
            if let data = file.readWithName(name) {
                value = data
            } else {
                _ = db.deleteItemWithKey(key: key)
            }
        case .sqlite:
            value = db.getValueWithKey(key: key)
        case .automatic:
            if let name = db.getFilenameWithKey(key: key) {
                if let data = file.readWithName(name) {
                    value = data
                } else {
                    _ = db.deleteItemWithKey(key: key)
                }
            } else {
                value = db.getValueWithKey(key: key)
            }
        }
        if value != nil {
            _ = db.updateAccessTimeWithKey(key: key)
        }
        return value
    }
    
    func itemsForKeys(keys: [String]) -> [KVStorageItem]? {
        guard keys.count > 0  else {
            return nil
        }
        guard var items = db.getItemsWithKeys(keys: keys, excludeInlineData: false),
            items.count > 0 else {
            return nil
        }
        if type != .sqlite {
            var temp = [KVStorageItem]()
            for item in items {
                var copy = item
                if let name = item.filename {
                    copy.value = file.readWithName(name)
                }
                temp.append(copy)
            }
            items = temp
        }
        if items.count > 0 {
            _ = db.updateAccessTimeWithKeys(keys: keys)
        }
        return items
    }
    
    
    func itemInfosForKeys(keys: [String]) -> [KVStorageItem]? {
        guard keys.count > 0  else {
            return nil
        }
        return db.getItemsWithKeys(keys: keys, excludeInlineData: true)
    }
    
    func itemValuesForKeys(keys: [String]) -> [String: Data]? {
        guard let items = itemsForKeys(keys: keys) else { return nil }
        var dict = [String: Data]()
        for i in items {
            if let data = i.value {
                dict[i.key] = data
            }
        }
        return dict
    }
    
    
    func containItemforKey(key: String) -> Bool {
        guard key.count > 0  else {
            return false
        }
        return (db.getItemCountWithKey(key: key) ?? 0) > 0
    }
    
    @discardableResult
    func remove(allItems: ()) -> Bool {
        guard db.close() else {
            return false
        }
        reset()
        guard db.open() && db.initialize() else {
            return false
        }
        return true
    }
    
}


// MARK: - KVStorageFile
fileprivate final class KVStorageFile {
    
    let dataPath: String
    let trashPath: String
    var invalidated = false
    let trashQueue: DispatchQueue
    
    init(dataPath: String, trashPath: String) {
        self.dataPath = dataPath
        self.trashPath = trashPath
        trashQueue = DispatchQueue(label: "com.kittenyang.KVStorage.disk.trash")
    }

    fileprivate func writeWithName(_ fileName: String, data: Data) -> Bool {
        guard !invalidated else {  return false }
        let path = (dataPath as NSString).appendingPathComponent(fileName)
        return (data as NSData).write(toFile: path, atomically: false)
    }
    
    fileprivate func readWithName(_ fileName: String) -> Data? {
        guard !invalidated else {  return nil }
        let path = (dataPath as NSString).appendingPathComponent(fileName)
        do {
            let data = try NSData(contentsOfFile: path, options: [])
            return data as Data
        } catch {
            return nil
        }
    }
    
    fileprivate func deleteWithName(_ fileName: String) -> Bool {
        guard !invalidated else {  return false }
        let path = (dataPath as NSString).appendingPathComponent(fileName)
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
    
    fileprivate func moveAllToTrash() -> Bool  {
        guard !invalidated else {  return false }
        
        let uuidRef = CFUUIDCreate(kCFAllocatorDefault)
        var tmpPath = trashPath
        if let uuid = CFUUIDCreateString(nil, uuidRef) {
            tmpPath = (trashPath as NSString).appendingPathComponent("\(uuid)")
        }
        do {
            try FileManager.default.moveItem(atPath: dataPath, toPath: tmpPath)
            try FileManager.default.createDirectory(atPath: dataPath, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    fileprivate func emptyTrashInBackground() {
        guard !invalidated else {  return }
        let path = trashPath
        trashQueue.async {
            let manager = FileManager()
            let directoryContents = (try? manager.contentsOfDirectory(atPath: path)) ?? []
            for subPath in directoryContents {
                let fullPath = (path as NSString).appendingPathComponent(subPath)
                _ = try? manager.removeItem(atPath: fullPath)
            }
        }
    }

}


// MARK: - KVStorageDatabase
fileprivate final class KVStorageDatabase {
    typealias sqlite3_stmt = OpaquePointer
    
    struct Config {
        static let fileName    = "manifest.sqlite";
        static let shmFileName = "manifest.sqlite-shm";
        static let walFileName = "manifest.sqlite-wal";
        static let lockFileName = "manifest.sqlite-lock";
        
    }
    
    fileprivate var db: OpaquePointer? = nil
    let dbPath: String
    var dbStmtCache = [String: sqlite3_stmt]()
    var invalidated = false
    var dbIsClosing = false

    init(path: String) {
        dbPath = path
    }

    fileprivate var isReady: Bool {
        return db != nil &&  !dbIsClosing && !invalidated
    }
    
    fileprivate var totalItemCount: Int32 {
        let sql = "select count(*) from manifest;"
        guard let stmt = prepareStmt(sql: sql) else { return 0 }
        return SQLiteDbUtil.selectData(stmt: stmt, binds: [:], select: [0])?[0]?.int32Value ?? 0
    }

    fileprivate var totalItemSize: Int32 {
        let sql = "select sum(size) from manifest;"
        guard let stmt = prepareStmt(sql: sql) else { return 0 }
        return SQLiteDbUtil.selectData(stmt: stmt, binds: [:], select: [0])?[0]?.int32Value ?? 0
    }
    
    fileprivate func open() -> Bool {
        guard !invalidated || dbIsClosing || db == nil else { return true }
        sqlite3_shutdown()
        sqlite3_initialize()
        return sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK//sqlite3_open(dbPath, &db) == SQLITE_OK
    }
    
    fileprivate func close() -> Bool {
        guard db != nil ||  dbIsClosing || invalidated else { return true }
        dbStmtCache.removeAll()
        var stmtFinalized = false
        while true {
            var retry = false
            let result = sqlite3_close(db)
            if (result == SQLITE_BUSY || result == SQLITE_LOCKED) {
                if (!stmtFinalized) {
                    stmtFinalized = true
                    while true {
                        var stmt : OpaquePointer? = nil
                        stmt = sqlite3_next_stmt(db, nil)

                        if stmt == nil || stmt?.hashValue == 0 { break }
                        sqlite3_finalize(stmt)
                        retry = true
                    }
                }
            } else if (result != SQLITE_OK) {
            }
            if !retry { break }
        }
        db = nil
        dbIsClosing = false
        return true
    }
    
    fileprivate func initialize() -> Bool {
        let sql = "pragma journal_mode = wal; pragma synchronous = normal; create table if not exists manifest (key text, filename text, size integer, inline_data blob, modification_time integer, last_access_time integer, primary key(key)); create index if not exists last_access_time_idx on manifest(last_access_time);"
        return execute(sql: sql)
    }
    
    fileprivate func checkpoint() {
        guard isReady else { return }
        sqlite3_wal_checkpoint(db, nil)
    }
    
    fileprivate func execute(sql: String) -> Bool {
        guard sql.count > 0 && isReady else { return false  }
        
        var error : UnsafeMutablePointer<Int8>? = nil
        let res = sqlite3_exec(db, sql, nil, nil, &error)
        return res == SQLITE_OK
    }
    
    fileprivate func prepareStmt(sql: String) -> sqlite_stmt? {
        guard isReady else { return nil }
        if let stmt = dbStmtCache[sql] {
            sqlite3_reset(stmt)
            return stmt
        } else {
            guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return nil }
            dbStmtCache[sql] = stmt
            return stmt
        }
    }
    
    fileprivate func saveWithKey(key: String, value: Data, fileName: String?) -> Bool {
        let sql = "insert or replace into manifest (key, filename, size, inline_data, modification_time, last_access_time) values (?1, ?2, ?3, ?4, ?5, ?6);"
        guard let stmt = prepareStmt(sql: sql) else { return false  }
        let timestamp = Int32(time(nil))
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, fileName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(value.count))
        if fileName?.isEmpty ?? true {
            sqlite3_bind_blob(stmt, 4, (value as NSData).bytes, Int32(value.count), SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_blob(stmt, 4, nil, 0, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int(stmt, 5, timestamp)
        sqlite3_bind_int(stmt, 6, timestamp)
        let result = sqlite3_step(stmt)
        return result == SQLITE_DONE
    }
    
    
    fileprivate func getItemFromStmt(stmt: sqlite_stmt, excludeInlineData: Bool) -> KVStorageItem? {
        func increase(_ i: inout Int32) ->  Int32 {
            defer { i = i + 1 }
            return i
        }
        var i: Int32 = 0
        guard let key = SQLiteDbUtil.string(stmt: stmt, index: increase(&i)) else { return nil }
        let filename = SQLiteDbUtil.string(stmt: stmt, index: increase(&i))
        let size = SQLiteDbUtil.int(stmt: stmt, index: increase(&i))
        let inline_data: Data? = excludeInlineData ? nil : SQLiteDbUtil.blob(stmt: stmt, index: increase(&i))
        if excludeInlineData { _ = increase(&i) }
        let modification_time = SQLiteDbUtil.int(stmt: stmt, index: increase(&i))
        let last_access_time = SQLiteDbUtil.int(stmt: stmt, index: increase(&i))
        return KVStorageItem(key: key, value: inline_data, filename: filename, size: size, modTime: modification_time, accessTime: last_access_time)
    }
    
    fileprivate func getItemWithKey(key: String, excludeInlineData: Bool) -> KVStorageItem? {
        let sql = excludeInlineData ? "select key, filename, size, modification_time, last_access_time from manifest where key = ?1;" : "select key, filename, size, inline_data, modification_time, last_access_time from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT);
        let result = sqlite3_step(stmt)
        if result == SQLITE_ROW {
            return getItemFromStmt(stmt: stmt, excludeInlineData: excludeInlineData)
        } else {
            return nil
        }
    }
    
    
    fileprivate func getItemsWithKeys(keys: [String], excludeInlineData: Bool) -> [KVStorageItem]? {
        guard isReady else { return nil }
        let keysStr = SQLiteDbUtil.joinedKeys(keys: keys) + " );"
        let sql = (excludeInlineData ? "select key, filename, size, modification_time, last_access_time from manifest where key in (" : "select key, filename, size, inline_data, modification_time, last_access_time from manifest where key in (") + keysStr
        
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return nil }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        var items = [KVStorageItem]()
        defer { sqlite3_finalize(stmt) }
        repeat {
            switch sqlite3_step(stmt) {
            case SQLITE_ROW:
                guard let item = getItemFromStmt(stmt: stmt, excludeInlineData: excludeInlineData) else { continue }
                items.append(item)
            case SQLITE_DONE:
                return items
            default:
                return nil
            }
        } while true
    }
    
    
    fileprivate func updateAccessTimeWithKey(key: String) -> Bool {
        let sql = "update manifest set last_access_time = ?1 where key = ?2;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.int(value: Int32(time(nil))), 2: SQLiteDataType.string(value: key)])
    }

    fileprivate func updateAccessTimeWithKeys(keys: [String]) -> Bool {
        guard isReady else { return false }
        let t = Int32(time(nil))
        let sql = "update manifest set last_access_time = \(t) where key in (\(SQLiteDbUtil.joinedKeys(keys: keys)));"
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return false }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        defer { sqlite3_finalize(stmt) }
        return SQLiteDbUtil.runStep(stmt: stmt)
    }

    fileprivate func deleteItemWithKey(key: String) -> Bool {
        let sql = "delete from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.string(value: key)])
    }
    
    fileprivate func deleteItemsWithKeys(keys: [String]) -> Bool {
        guard isReady else { return false }
        let sql = "delete from manifest where key in (\(SQLiteDbUtil.joinedKeys(keys: keys)));"
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return false }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        defer { sqlite3_finalize(stmt) }
        return SQLiteDbUtil.runStep(stmt: stmt)
    }
    
    fileprivate func deleteItemsWithSizeLargerThan(size: Int32) -> Bool {
        let sql = "delete from manifest where size > ?1;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.int(value: size)])
    }
    
    fileprivate func deleteItemsWithTimeEarlierThan(time: Int32) -> Bool {
        let sql = "delete from manifest where last_access_time < ?1;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.int(value: time)])
    }

    fileprivate func getValueWithKey(key: String) -> Data? {
        let sql = "select inline_data from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        return SQLiteDbUtil.selectData(stmt: stmt,
                                   binds: [1: SQLiteDataType.string(value: key)],
                                   select: [0])?[0]?.blobValue
    }
    
    fileprivate func getFilenameWithKey(key: String) -> String? {
        let sql = "select filename from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        return SQLiteDbUtil.selectData(stmt: stmt,
                                       binds: [1: SQLiteDataType.string(value: key)],
                                       select: [0])?[0]?.stringValue
 
    }


    fileprivate func getFilenamesWithKeys(keys: [String]) -> [String]? {
        guard isReady else { return nil }
        let sql = "select filename from manifest where key in " + SQLiteDbUtil.joinedKeys(keys: keys) + " ;"
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return nil }
        defer {  sqlite3_finalize(stmt) }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt, binds: [:], select: [0]) else { return nil }
        return datas.compactMap { $0[0]?.stringValue }
    }
    
    
    fileprivate func getFilenamesWithSizeLargerThan(size: Int32) -> [String]? {
        let sql = "select filename from manifest where size > ?1 and filename is not null;"
        guard  let stmt = prepareStmt(sql: sql) else { return nil }
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt,
                                                  binds: [1: SQLiteDataType.int(value: size)],
                                                  select: [0]) else { return nil}
        return datas.compactMap { $0[0]?.stringValue }
    }
    
    fileprivate func getFilenamesWithTimeEarlierThan(time: Int32) -> [String]? {
    
        let sql = "select filename from manifest where last_access_time < ?1 and filename is not null;"
        guard  let stmt = prepareStmt(sql: sql) else { return nil }
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt,
                                                  binds: [1: SQLiteDataType.int(value: time)],
                                                  select: [0]) else { return nil}
        return datas.compactMap { $0[0]?.stringValue }
    }

    fileprivate func getItemSizeInfoOrderByTimeDescWithLimit(count: Int32) -> [KVStorageItemSample]? {
        let sql = "select key, filename, size from manifest order by last_access_time desc limit ?1;"
        guard  let stmt = prepareStmt(sql: sql) else { return nil }
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt,
                                                  binds: [1: SQLiteDataType.int(value: count)],
                                                  select: [0, 1, 2]) else { return nil}
        
        return datas.compactMap { value -> KVStorageItemSample? in
            guard let key = value[0]?.stringValue else { return nil }
            let filename = value[1]?.stringValue
            let size = value[2]?.intValue ?? 0
            return (key, filename, Int32(size))
        }
    }

    fileprivate func getItemCountWithKey(key: String) -> Int? {
        let sql = "select count(key) from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        let count = SQLiteDbUtil.selectData(stmt: stmt,
                                            binds: [1: SQLiteDataType.string(value: key)],
                                            select: [0])?[0]?.intValue
        return count
    }
    
}
