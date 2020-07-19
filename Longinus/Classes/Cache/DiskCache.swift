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

    static var diskCount: Int = 0
    
    private var storage: KVStorage<Key>?//DiskStorage
    private let sizeThreshold: Int32
    private let queue: DispatchQueuePool
    private let ioLock: DispatchSemaphore
    
    private(set) var costLimit: Int32
    private(set) var countLimit: Int32
    private(set) var ageLimit: CacheAge
    private(set) var autoTrimInterval: TimeInterval
    
    public var shouldAutoTrim: Bool {
        didSet {
            if oldValue == shouldAutoTrim { return }
            if shouldAutoTrim {
                autoTrim()
            }
        }
    }
    
    public var totalCount: Int32 {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        let count = storage?.totalItemCount ?? 0
        defer { ioLock.signal() }
        return count
    }
    
    public var totalCost: Int32 {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        let count = storage?.totalItemSize ?? 0
        defer { ioLock.signal() }
        return count
    }

    required public init?(path: String, sizeThreshold threshold: Int32) {
        var type = KVStorageType.automatic
        if threshold == 0 {
            type = .file
        } else if threshold == Int32.max {
            type = .sqlite
        }
        if let currentStorage = KVStorage<Key>(path: path, type: type) {
            storage = currentStorage
        } else {
            return nil
        }
        ioLock = DispatchSemaphore(value: 1)
        sizeThreshold = threshold
        queue = DispatchQueuePool.default //DispatchQueue(label: LonginusPrefixID + ".disk", attributes: .concurrent)
        self.countLimit = Int32.max
        self.costLimit = Int32.max
        self.ageLimit = .never
        self.autoTrimInterval = 60
        self.shouldAutoTrim = true
        
        if shouldAutoTrim { autoTrim() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillBeTerminated), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    @objc private func appWillBeTerminated() {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        storage = nil
        ioLock.signal()
    }
    
}

// MARK: CacheStandard
extension DiskCache {
    public func containsObject(key: Key) -> Bool {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        defer { ioLock.signal() }
        return storage?.containItemforKey(key: key) ?? false
    }
    
    public func query(key: Key) -> Value? {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        let value = storage?.itemValueForKey(key: key)
        DiskCache.diskCount += 1
        let newCount = DiskCache.diskCount
        ioLock.signal()
        print("获取 disk 缓存：\(newCount) 个")
        return value
    }
    
    public func save(value: Value, for key: Key) {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        storage?.save(key: key, value: value, filename: (value.count > sizeThreshold) ? key.lg.md5 : nil)
        ioLock.signal()
    }
    
    public func remove(key: Key) {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        storage?.remove(forKey: key)
        ioLock.signal()
    }
    
    public func removeAll() {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        storage?.remove(allItems: ())
        ioLock.signal()
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
    
    public func save(_ dataWork: @escaping () -> Data?, forKey key: String, result: @escaping (() -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = dataWork() {
                self.save(value: data, for: key)
            }
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
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        storage?.remove(earlierThan: age.timeInterval)
        ioLock.signal()
    }
    
    func trimToCost(_ cost: Int32) {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        storage?.remove(toFitSize: cost)
        ioLock.signal()
    }
    
    func trimToCount(_ count: Int32) {
        _ = ioLock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        storage?.remove(toFitCount: count)
        ioLock.signal()
    }
    
}
