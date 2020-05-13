//
//  DiskCache.swift
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

public class DiskCache: DiskCacheable {

    public typealias Key = String
    public typealias Value = Data

    private let storage: DiskStorage
    private let sizeThreshold: Int
    private let queue: DispatchQueuePool
    
    private(set) var costLimit: Int
    private(set) var countLimit: Int
    private(set) var ageLimit: CacheAge
    private(set) var autoTrimInterval: TimeInterval
    
    var shouldAutoTrim: Bool {
        didSet {
            if oldValue == shouldAutoTrim { return }
            if shouldAutoTrim {
                autoTrim()
            }
        }
    }

    required public init?(path: String, sizeThreshold threshold: Int) {
        if let currentStorage = DiskStorage(path: path) {
            storage = currentStorage
        } else {
            return nil
        }
        sizeThreshold = threshold
        queue = DispatchQueuePool.utility
        self.countLimit = Int.max
        self.costLimit = Int.max
        self.ageLimit = .never
        self.autoTrimInterval = 5
        self.shouldAutoTrim = true
        
        if shouldAutoTrim { autoTrim() }
    }
    
}

// MARK: CacheStandard
extension DiskCache {
    public func containsObject(key: Key) -> Bool {
        return storage.dataExists(forKey: key)
    }
    
    public func query(key: Key) -> Value? {
        return storage.data(forKey: key)
    }
    
    public func save(value: Value, for key: Key) {
        storage.store(value, forKey: key, type: (value.count > sizeThreshold ? .file : .sqlite))
    }
    
    public func remove(key: Key) {
        storage.removeData(forKey: key)
    }
    
    public func removeAll() {
        storage.clear()
    }
}

// MARK: CacheAsyncStandard
extension DiskCache {
    public func containsObject(key: Key, _ result: @escaping ((Key, Bool) -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            result(key, self.containsObject(key: key))
        }
    }
    
    public func query(key: Key, _ result: @escaping ((Key, Value?) -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            result(key, self.query(key: key))
        }
    }
    
    public func save(value: Value, for key: Key, _ result: @escaping (() -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.save(value: value, for: key)
            result()
        }
    }
    
    public func remove(key: Key, _ result: @escaping ((Key) -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.remove(key: key)
            result(key)
        }
    }
    
    public func removeAll(_ result: @escaping (() -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.removeAll()
            result()
        }
    }
}

extension DiskCache: AutoTrimable {
    
    func trimToAge(_ age: CacheAge) {
        self.storage.trim(toAge: age)
    }
    
    func trimToCost(_ cost: Int) {
        self.storage.trim(toCost: cost)
    }
    
    func trimToCount(_ count: Int) {
        self.storage.trim(toCount: count)
    }
    
}
