//
//  SQLiteUtil.swift
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
#if os(OSX)
    import SQLiteMacOSX
    #elseif os(iOS)
#if (arch(i386) || arch(x86_64))
    import SQLite3
    #else
    import SQLite3//SQLiteiPhoneOS
#endif
    #elseif os(watchOS)
#if (arch(i386) || arch(x86_64))
    import SQLiteWatchSimulator
    #else
    import SQLiteWatchOS
#endif
#endif
#endif



typealias sqlitedb = OpaquePointer
typealias sqlite_stmt = OpaquePointer

let SQLITE_TRANSIENT = unsafeBitCast(-1, to:sqlite3_destructor_type.self)

struct SQLiteDbUtil {

    static func joinedKeys(keys: [String]) -> String {
        var string = ""
        for i in 0..<keys.count {
            string += "?"
            if i + 1 != keys.count {
                string += ","
            }
        }
        return string
    }
    
    
    static func prepare(db: sqlitedb?, sql: String) -> sqlite_stmt? {
        guard let database = db else { return nil }
        var s: sqlite_stmt? = nil
        let result = sqlite3_prepare_v2(database, sql, -1, &s, nil)
        guard result == SQLITE_OK, let stmt = s, stmt.hashValue != 0 else { return nil }
        return s
    }
    
    static func bindJoinedKeys(keys: [String], stmt: sqlite_stmt, fromIndex index: Int32) {
        for i in 0..<keys.count {
            let key = keys[i]
            sqlite3_bind_text(stmt, index.advanced(by: i), key, -1, SQLITE_TRANSIENT)
        }
    }
    
    static func int(stmt: sqlite_stmt, index: Int32) -> Int {
        return Int(sqlite3_column_int64(stmt, Int32(index)))
    }
    
    static func string(stmt: sqlite_stmt, index: Int32) -> String? {
        let cString = sqlite3_column_text(stmt, Int32(index))
        guard let cs = cString, cs.hashValue != 0 else { return nil }
        return String(cString: cs)
    }
    
    static func double(stmt: sqlite_stmt, index: Int32) -> Double {
        return sqlite3_column_double(stmt, Int32(index))
    }
    
    static func blob(stmt: sqlite_stmt, index: Int32) -> Data? {
        let bytes = unsafeBitCast(sqlite3_column_blob(stmt, Int32(index)), to: UnsafePointer<UInt8>.self)
        let count = Int(sqlite3_column_bytes(stmt, Int32(index)))
        guard count > 0 else { return nil }
        return Data(bytes: bytes, count: count)
    }
    
    static func bytes(stmt: sqlite_stmt, index: Int32) -> Int {
        return Int(sqlite3_column_bytes(stmt, Int32(index)))
    }
    
    
    static func columnData(stmt: sqlite_stmt, index: Int32) -> SQLiteDataType? {
        switch sqlite3_column_type(stmt, Int32(index)) {
        case SQLITE_NULL:
            return SQLiteDataType.null
        case SQLITE_INTEGER:
            let v = SQLiteDbUtil.int(stmt: stmt, index: index)
            return SQLiteDataType.int(value: Int32(v))
        case SQLITE_TEXT:
            guard let v = SQLiteDbUtil.string(stmt: stmt, index: index) else { return nil }
            return SQLiteDataType.string(value: v)
        case SQLITE_FLOAT:
            let v = SQLiteDbUtil.double(stmt: stmt, index: index)
            return SQLiteDataType.double(value: v)
        case SQLITE_BLOB:
            guard  let v = SQLiteDbUtil.blob(stmt: stmt, index: index) else { return nil }
            return SQLiteDataType.blob(value: v)
        default:
            return nil
        }
    }

    
    
    static func runStep(stmt: sqlite_stmt, binds: [Int32: SQLiteDataType] = [:]) -> Bool {
        for (i, b) in binds {
            b.bindStatement(stmt: stmt, index: i)
        }
        let result = sqlite3_step(stmt)
        return result ==  SQLITE_DONE
    }


    static func selectDatas(stmt: sqlite_stmt, binds: [Int32: SQLiteDataType], select: [Int32]) -> [[Int32: SQLiteDataType]]? {
        for (i, b) in binds {
            b.bindStatement(stmt: stmt, index: i)
        }
        var items = [[Int32: SQLiteDataType]]()
        repeat {
            switch sqlite3_step(stmt) {
            case SQLITE_ROW:
                var temp = [Int32: SQLiteDataType]()
                for index in select {
                    if let v = columnData(stmt: stmt, index: index) {
                        temp[index] = v
                    }
                }
                items.append(temp)
            case SQLITE_DONE:
                return items
            default:
                return nil
            }
        } while true
    }
    
    static func selectData(stmt: sqlite_stmt, binds: [Int32: SQLiteDataType], select: [Int32]) -> [Int32: SQLiteDataType]? {
        for (i, b) in binds {
            b.bindStatement(stmt: stmt, index: i)
        }
        
        switch sqlite3_step(stmt) {
        case SQLITE_ROW:
            var temp = [Int32: SQLiteDataType]()
            for index in select {
                if let v = columnData(stmt: stmt, index: index) {
                    temp[index] = v
                }
            }
            return temp
        default:
            return nil
        }
    }
    
    
    
}

enum SQLiteDataType {
    case null
    case int(value: Int32)
    case string(value: String)
    case double(value: Double)
    case blob(value: Data)
    case byte(value: Int)
    
    var int32Value: Int32? {
        switch self {
        case .int(let value):
            return value
        case .byte(let value):
            return Int32(value)
        default:
            return nil
        }
    }
    
    var stringValue: String? {
        guard case let .string(value: v) = self else { return nil }
        return v
    }
    
    var doubleValue: Double? {
        guard case let .double(value: v) = self else { return nil }
        return v
    }

    var blobValue: Data? {
        guard case let .blob(value: v) = self else { return nil }
        return v
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return Int(value)
        case .byte(let value):
            return value
        default:
            return nil
        }
    }

    
    func bindStatement(stmt: sqlite_stmt, index: Int32)  {
        switch self {
        case .int(let value):
            sqlite3_bind_int(stmt, index, value)
        case .string(let value):
            sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
        case .double(let value):
            sqlite3_bind_double(stmt, index, value)
        case .byte(let value):
            sqlite3_bind_int(stmt, index, Int32(value))
        case .blob(let value):
            sqlite3_bind_blob(stmt, index, (value as NSData).bytes, Int32(value.count), SQLITE_TRANSIENT)
        case .null:
            sqlite3_bind_null(stmt, index)
        }
    }
    
    
    
    static func countByte(stmt: sqlite_stmt, index: Int32) -> SQLiteDataType {
        let v = Int(sqlite3_column_bytes(stmt, Int32(index)))
        return SQLiteDataType.byte(value: v)
    }
}
