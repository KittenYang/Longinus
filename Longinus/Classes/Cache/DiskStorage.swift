//
//  DiskStorage.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/12.
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
import SQLite3
import CommonCrypto

private struct DiskStorageItem {
    let key: String
    var filename: String?
    var data: Data?
    let size: Int32
    let lastAccessTime: TimeInterval
}

/// DiskStorageType specifies how data is stored
public enum DiskStorageType {
    /// Data is stored in file
    case file
    
    /// Data is store in sqlite
    case sqlite
}

public class DiskStorage {
    private let ioLock: DispatchSemaphore
    private let baseDataPath: String
    private var database: OpaquePointer?
    
    public init?(path: String) {
        ioLock = DispatchSemaphore(value: 1)
        baseDataPath = path + "/Data"
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch _ {
            print("Fail to create LGSCache base path")
            return nil
        }
        do {
            try FileManager.default.createDirectory(atPath: baseDataPath, withIntermediateDirectories: true)
        } catch _ {
            print("Fail to create LGSCache base data path")
            return nil
        }
        let databasePath = path + "/LGSCache.sqlite"
        if sqlite3_open(databasePath, &database) != SQLITE_OK {
            print("Fail to open sqlite at \(databasePath)")
            try? FileManager.default.removeItem(atPath: databasePath)
            return nil
        }
        let sql = "PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; CREATE TABLE IF NOT EXISTS Storage_item (key text PRIMARY KEY, filename text, data blob, size integer, last_access_time real); CREATE INDEX IF NOT EXISTS last_access_time_index ON Storage_item(last_access_time);"
        if sqlite3_exec(database, sql.lg.utf8, nil, nil, nil) != SQLITE_OK {
            print("Fail to create LGSCache sqlite Storage_item table")
            try? FileManager.default.removeItem(atPath: path)
            return nil
        }
    }
    
    deinit {
        ioLock.wait()
        if let db = database { sqlite3_close(db) }
        ioLock.signal()
    }
 
    public func data(forKey key: String) -> Data? {
        if key.isEmpty { return nil }
        ioLock.wait()
        var data: Data?
        let sql = "SELECT filename, data, size FROM Storage_item WHERE key = '\(key)';"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
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
                    if sqlite3_exec(database, sql.lg.utf8, nil, nil, nil) != SQLITE_OK {
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

    public func dataExists(forKey key: String) -> Bool {
        if key.isEmpty { return false }
        ioLock.wait()
        var exists = false
        let sql = "SELECT count(*) FROM Storage_item WHERE key = '\(key)';"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
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
    
    public func store(_ data: Data, forKey key: String, type: DiskStorageType) {
        if key.isEmpty { return }
        ioLock.wait()
        let sql = "INSERT OR REPLACE INTO Storage_item (key, filename, data, size, last_access_time) VALUES (?1, ?2, ?3, ?4, ?5);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key.lg.utf8, -1, nil)
            let nsdata = data as NSData
            if type == .file {
                let filename = key.lg.md5
                sqlite3_bind_text(stmt, 2, filename.lg.utf8, -1, nil)
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
    
    
    public func removeData(forKey key: String) {
        if key.isEmpty { return }
        ioLock.wait()
        _removeData(forKey: key)
        ioLock.signal()
    }
    
    public func clear() {
        ioLock.wait()
        let sql = "DELETE FROM Storage_item;"
        if sqlite3_exec(database, sql.lg.utf8, nil, nil, nil) != SQLITE_OK {
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
    
    public func trim(toAge age: CacheAge) {
        if age.timeInterval == .greatestFiniteMagnitude { return }
        if age.timeInterval <= 0 { return clear() }
        ioLock.wait()
        let time = Date().timeIntervalSince1970 - age.timeInterval
        if let filenames = filenamesEarlierThan(time) {
            for filename in filenames {
                try? FileManager.default.removeItem(atPath: "\(baseDataPath)/\(filename)")
            }
        }
        removeDataEarlierThan(time)
        ioLock.signal()
    }
    
}

// MARK: Private Methods
extension DiskStorage {
    private func _removeData(forKey key: String) {
        // Get filename and delete file data
        let selectSql = "SELECT filename FROM Storage_item WHERE key = '\(key)';"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, selectSql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
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
        if sqlite3_exec(database, sql.lg.utf8, nil, nil, nil) != SQLITE_OK {
            print("Fail to remove data for key \(key)")
        }
    }
    
    private func itemsForTrimming(withLimit limit: Int) -> [DiskStorageItem]? {
        var items: [DiskStorageItem]?
        let sql = "SELECT key, size FROM Storage_item ORDER BY last_access_time LIMIT \(limit);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, sql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
            items = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                var key: String = ""
                if let keyPointer = sqlite3_column_text(stmt, 0) {
                    key = String(cString: keyPointer)
                }
                let size: Int32 = sqlite3_column_int(stmt, 1)
                items?.append(DiskStorageItem(key: key, filename: nil, data: nil, size: size, lastAccessTime: 0))
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
        if sqlite3_prepare_v2(database, sql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
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
        if sqlite3_prepare_v2(database, sql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
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
        if sqlite3_prepare_v2(database, sql.lg.utf8, -1, &stmt, nil) == SQLITE_OK {
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
        if sqlite3_exec(database, sql.lg.utf8, nil, nil, nil) != SQLITE_OK {
            print("Fail to remove data earlier than \(time)")
        }
    }
}

extension LonginusExtension where Base == String {
    var utf8: UnsafePointer<Int8>? { return (self.base as NSString).utf8String }
    var md5: String {
        guard let data = self.base.data(using: .utf8) else { return self.base }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
