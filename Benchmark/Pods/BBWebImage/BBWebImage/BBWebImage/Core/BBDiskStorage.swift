//
//  BBDiskStorage.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/29.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit
import SQLite3

private struct BBDiskStorageItem {
    let key: String
    var filename: String?
    var data: Data?
    let size: Int32
    let lastAccessTime: TimeInterval
}

/// BBDiskStorageType specifies how data is stored
public enum BBDiskStorageType {
    /// Data is stored in file
    case file
    
    /// Data is store in sqlite
    case sqlite
}

/// BBDiskStorage is a thread safe key-value disk cache using least recently used algorithm
public class BBDiskStorage {
    private let ioLock: DispatchSemaphore
    private let baseDataPath: String
    private var database: OpaquePointer?
    
    /// Creates a BBDiskStorage object
    ///
    /// - Parameter path: directory storing data
    public init?(path: String) {
        ioLock = DispatchSemaphore(value: 1)
        baseDataPath = path + "/Data"
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch _ {
            print("Fail to create BBCache base path")
            return nil
        }
        do {
            try FileManager.default.createDirectory(atPath: baseDataPath, withIntermediateDirectories: true)
        } catch _ {
            print("Fail to create BBCache base data path")
            return nil
        }
        let databasePath = path + "/BBCache.sqlite"
        if sqlite3_open(databasePath, &database) != SQLITE_OK {
            print("Fail to open sqlite at \(databasePath)")
            try? FileManager.default.removeItem(atPath: databasePath)
            return nil
        }
        let sql = "PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; CREATE TABLE IF NOT EXISTS Storage_item (key text PRIMARY KEY, filename text, data blob, size integer, last_access_time real); CREATE INDEX IF NOT EXISTS last_access_time_index ON Storage_item(last_access_time);"
        if sqlite3_exec(database, sql.bb_utf8, nil, nil, nil) != SQLITE_OK {
            print("Fail to create BBCache sqlite Storage_item table")
            try? FileManager.default.removeItem(atPath: path)
            return nil
        }
    }
    
    deinit {
        ioLock.wait()
        if let db = database { sqlite3_close(db) }
        ioLock.signal()
    }
    
    /// Gets data with key
    ///
    /// - Parameter key: cache key
    /// - Returns: data in disk, or nil if no data found
    public func data(forKey key: String) -> Data? {
        if key.isEmpty { return nil }
        ioLock.wait()
        var data: Data?
        let sql = "SELECT filename, data, size FROM Storage_item WHERE key = '\(key)';"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let filenamePointer = sqlite3_column_text(stmt, 0)
                let dataPointer = sqlite3_column_blob(stmt, 1)
                let size = sqlite3_column_int(stmt, 2)
                if let currentDataPointer = dataPointer,
                    size > 0 {
                    // Get data from database
                    data = Data(bytes: currentDataPointer, count: Int(size))
                } else if let currentFilenamePointer = filenamePointer {
                    // Get data from data file
                    let filename = String(cString: currentFilenamePointer)
                    data = try? Data(contentsOf: URL(fileURLWithPath: "\(baseDataPath)/\(filename)"))
                }
                if data != nil {
                    // Update last access time
                    let sql = "UPDATE Storage_item SET last_access_time = \(CACurrentMediaTime()) WHERE key = '\(key)';"
                    if sqlite3_exec(database, sql.bb_utf8, nil, nil, nil) != SQLITE_OK {
                        print("Fail to set last_access_time for key \(key)")
                    }
                }
            }
            sqlite3_finalize(stmt)
        } else {
            print("Can not select data")
        }
        ioLock.signal()
        return data
    }
    
    /// Checks whether data is in the disk cache.
    ///
    /// - Parameters:
    ///   - key: cache key
    /// - Returns: true if data is in the cache, or false if not
    public func dataExists(forKey key: String) -> Bool {
        if key.isEmpty { return false }
        ioLock.wait()
        var exists = false
        let sql = "SELECT count(*) FROM Storage_item WHERE key = '\(key)';"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if sqlite3_column_int(stmt, 0) >= 1 { exists = true }
            }
            sqlite3_finalize(stmt)
        } else {
            print("Can not select data when checking whether data is in disk cache")
        }
        ioLock.signal()
        return exists
    }
    
    /// Stores data with key and type
    ///
    /// - Parameters:
    ///   - data: data to store
    ///   - key: cache key
    ///   - type: storage type specifying how data is stored
    public func store(_ data: Data, forKey key: String, type: BBDiskStorageType) {
        if key.isEmpty { return }
        ioLock.wait()
        let sql = "INSERT OR REPLACE INTO Storage_item (key, filename, data, size, last_access_time) VALUES (?1, ?2, ?3, ?4, ?5);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key.bb_utf8, -1, nil)
            let nsdata = data as NSData
            if type == .file {
                let filename = key.bb_md5
                sqlite3_bind_text(stmt, 2, filename.bb_utf8, -1, nil)
                sqlite3_bind_blob(stmt, 3, nil, 0, nil)
                try? data.write(to: URL(fileURLWithPath: "\(baseDataPath)/\(filename)"))
            } else {
                sqlite3_bind_text(stmt, 2, nil, -1, nil)
                sqlite3_bind_blob(stmt, 3, nsdata.bytes, Int32(nsdata.length), nil)
            }
            sqlite3_bind_int(stmt, 4, Int32(nsdata.length))
            sqlite3_bind_double(stmt, 5, CACurrentMediaTime())
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("Fail to insert data for key \(key)")
            }
            sqlite3_finalize(stmt)
        }
        ioLock.signal()
    }
    
    /// Removes data with key
    ///
    /// - Parameter key: cache key
    public func removeData(forKey key: String) {
        if key.isEmpty { return }
        ioLock.wait()
        _removeData(forKey: key)
        ioLock.signal()
    }
    
    /// Removes all data
    public func clear() {
        ioLock.wait()
        let sql = "DELETE FROM Storage_item;"
        if sqlite3_exec(database, sql.bb_utf8, nil, nil, nil) != SQLITE_OK {
            print("Fail to delete data")
        }
        if let enumerator = FileManager.default.enumerator(atPath: baseDataPath) {
            for next in enumerator {
                if let path = next as? String {
                    try? FileManager.default.removeItem(atPath: "\(baseDataPath)/\(path)")
                }
            }
        }
        ioLock.signal()
    }
    
    public func trim(toCost cost: Int) {
        if cost == .max { return }
        if cost <= 0 { return clear() }
        ioLock.wait()
        var totalCost = totalItemSize()
        while totalCost > cost {
            if let items = itemsForTrimming(withLimit: 16) {
                for item in items {
                    if totalCost > cost {
                        _removeData(forKey: item.key)
                        totalCost -= Int(item.size)
                    } else {
                        break
                    }
                }
            } else {
                break
            }
        }
        ioLock.signal()
    }
    
    public func trim(toCount count: Int) {
        if count == .max { return }
        if count <= 0 { return clear() }
        ioLock.wait()
        var totalCount = totalItemCount()
        while totalCount > count {
            if let items = itemsForTrimming(withLimit: 16) {
                for item in items {
                    if totalCount > count {
                        _removeData(forKey: item.key)
                        totalCount -= 1
                    } else {
                        break
                    }
                }
            } else {
                break
            }
        }
        ioLock.signal()
    }
    
    public func trim(toAge age: TimeInterval) {
        if age == .greatestFiniteMagnitude { return }
        if age <= 0 { return clear() }
        ioLock.wait()
        let time = CACurrentMediaTime() - age
        if let filenames = filenamesEarlierThan(time) {
            for filename in filenames {
                try? FileManager.default.removeItem(atPath: "\(baseDataPath)/\(filename)")
            }
        }
        removeDataEarlierThan(time)
        ioLock.signal()
    }
    
    private func _removeData(forKey key: String) {
        // Get filename and delete file data
        let selectSql = "SELECT filename FROM Storage_item WHERE key = '\(key)';"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, selectSql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let filenamePointer = sqlite3_column_text(stmt, 0) {
                    let filename = String(cString: filenamePointer)
                    try? FileManager.default.removeItem(atPath: "\(baseDataPath)/\(filename)")
                }
            }
            sqlite3_finalize(stmt)
        }
        // Delete from database
        let sql = "DELETE FROM Storage_item WHERE key = '\(key)';"
        if sqlite3_exec(database, sql.bb_utf8, nil, nil, nil) != SQLITE_OK {
            print("Fail to remove data for key \(key)")
        }
    }
    
    private func itemsForTrimming(withLimit limit: Int) -> [BBDiskStorageItem]? {
        var items: [BBDiskStorageItem]?
        let sql = "SELECT key, size FROM Storage_item ORDER BY last_access_time LIMIT \(limit);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            items = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                var key: String = ""
                if let keyPointer = sqlite3_column_text(stmt, 0) {
                    key = String(cString: keyPointer)
                }
                let size: Int32 = sqlite3_column_int(stmt, 1)
                items?.append(BBDiskStorageItem(key: key, filename: nil, data: nil, size: size, lastAccessTime: 0))
            }
            if items?.count == 0 { items = nil }
            sqlite3_finalize(stmt)
        }
        return items
    }
    
    private func totalItemSize() -> Int {
        var size: Int = 0
        let sql = "SELECT sum(size) FROM Storage_item;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                size = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }
        return size
    }
    
    private func totalItemCount() -> Int {
        var count: Int = 0
        let sql = "SELECT count(*) FROM Storage_item;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }
        return count
    }
    
    private func filenamesEarlierThan(_ time: TimeInterval) -> [String]? {
        var filenames: [String]?
        let sql = "SELECT filename FROM Storage_item WHERE last_access_time < \(time) AND filename IS NOT NULL;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.bb_utf8, -1, &stmt, nil) == SQLITE_OK {
            filenames = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let filenamePointer = sqlite3_column_text(stmt, 0) {
                    filenames?.append(String(cString: filenamePointer))
                }
            }
            if filenames?.count == 0 { filenames = nil }
            sqlite3_finalize(stmt)
        }
        return filenames
    }
    
    private func removeDataEarlierThan(_ time: TimeInterval) {
        let sql = "DELETE FROM Storage_item WHERE last_access_time < \(time);"
        if sqlite3_exec(database, sql.bb_utf8, nil, nil, nil) != SQLITE_OK {
            print("Fail to remove data earlier than \(time)")
        }
    }
}

fileprivate extension String {
    var bb_utf8: UnsafePointer<Int8>? { return (self as NSString).utf8String }
}
