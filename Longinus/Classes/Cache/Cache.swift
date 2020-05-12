//
//  Cache.swift
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

public struct Cache<MT, DT>: Cacheable where MT: CacheStandard, DT: CacheStandard & CacheAsyncStandard, MT.Key == DT.Key, MT.Value == DT.Value {
    
    public typealias M = MT
    public typealias D = DT
    
    public typealias Value = M.Value
    public typealias Key = M.Key
    
    private var memoryCache: M
    private var diskCache: D
    
    public init(memoryCache: M, diskCache: D) {
        self.memoryCache = memoryCache
        self.diskCache = diskCache
    }
}

extension Cache: CacheStandard {

    public func containsObject(key: Key) -> Bool {
        return memoryCache.containsObject(key: key) || diskCache.containsObject(key: key)
    }

    mutating public func query(key: Key) -> Value? {
        var value: Value? = memoryCache.query(key: key)
        if value == nil {
            value = diskCache.query(key: key)
            if let value = value {
                memoryCache.save(value: value, for: key)
            }
        }

        return value
    }

    mutating public func save(value: Value, for key: Key) {
        memoryCache.save(value: value, for: key)
        diskCache.save(value: value, for: key)
    }

    mutating public func remove(key: Key) {
        memoryCache.remove(key: key)
        diskCache.remove(key: key)
    }

    mutating public func removeAll() {
        memoryCache.removeAll()
        diskCache.removeAll()
    }
}

extension Cache: CacheAsyncStandard {
    public func containsObject(key: Key, _ result: @escaping ((Key, Bool) -> Void)) {
        if memoryCache.containsObject(key: key) {
            DispatchQueue.global().async {
                result(key, true)
            }
        } else {
            diskCache.containsObject(key: key, result)
        }
    }

    mutating public func query(key: Key, _ result: @escaping ((Key, Value?) -> Void)) {
        if let value: Value = memoryCache.query(key: key) {
            DispatchQueue.global().async {
                result(key, value)
            }
        } else {
            diskCache.query(key: key, result)
        }
    }

    mutating public func save(value: Value, for key: Key, _ result: @escaping (() -> Void)) {
        memoryCache.save(value: value, for: key)
        diskCache.save(value: value, for: key, result)
    }

    mutating public func remove(key: Key, _ result: @escaping ((Key) -> Void)) {
        memoryCache.remove(key: key)
        diskCache.remove(key: key, result)
    }

    mutating public func removeAll(_ result: @escaping (() -> Void)) {
        memoryCache.removeAll()
        diskCache.removeAll(result)
    }
}
