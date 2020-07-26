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

/**
DiskCache is a thread-safe cache that stores key-value pairs backed by SQLite
and file system.

DiskCache has these features:

* It use LRU (least-recently-used) to remove objects.
* It can be controlled by cost, count, and age.
* It can automatically decide the storage type (sqlite/file) for each object to get
     better performance.
*/
public class DiskCache: DiskCacheable {
    
    /*
     Represents DiskCache can store [String:Data] key-value pairs to the disk.
     */
    public typealias Key = String
    public typealias Value = Data
    
    /**
    The maximum total cost that the cache can hold before it starts evicting objects.
    
    @discussion The default value is `Int32.max`, which means no limit.
    This is not a strict limit — if the cache goes over the limit, some objects in the
    cache could be evicted later in background queue.
    */
    public var costLimit: Int32
    
    /**
    The maximum number of objects the cache should hold.
    
    @discussion The default value is `Int32.max`, which means no limit.
    This is not a strict limit — if the cache goes over the limit, some objects in the
    cache could be evicted later in background queue.
    */
    public var countLimit: Int32
    
    /**
    The maximum expiry time of objects in cache.
    
    @discussion The default value is `.never`, which means no limit.
    This is not a strict limit — if an object goes over the limit, the objects could
    be evicted later in background queue.
    */
    public var ageLimit: CacheAge
    
    /**
    The auto trim check time interval in seconds. Default is 60 (1 minute).
    */
    public var autoTrimInterval: TimeInterval
    
    /**
    Determine whether need to enable auto trim check
    */
    public var shouldAutoTrim: Bool {
        didSet {
            if oldValue == shouldAutoTrim { return }
            if shouldAutoTrim {
                autoTrim()
            }
        }
    }
    
    /**
    Get the totalCount of storage.
    */
    public var totalCount: Int32 {
        _ = ioLock.lock()
        let count = storage?.totalItemCount ?? 0
        defer { ioLock.unlock() }
        return count
    }
    
    /**
    Get the totalCost of storage.
    */
    public var totalCost: Int32 {
        _ = ioLock.lock()
        let count = storage?.totalItemSize ?? 0
        defer { ioLock.unlock() }
        return count
    }
    
    /*
     The underlying SQLite storage object.
     */
    private var storage: KVStorage<Key>?
    /*
     The size threshold to determine save data to sqlite or file.
     */
    private let sizeThreshold: Int32
    
    /*
     The background queue for runnig disk save/query/remove operations.
     */
    private let queue = DispatchQueuePool.default
    /*
     The lock to ensure datas' safety
     */
    private let ioLock: DispatchSemaphore
    
    /**
     The designated initializer.
     
     The data store inline threshold in bytes. If the object's data
     size (in bytes) is larger than this value, then object will be stored as a
     file, otherwise the object will be stored in sqlite. 0 means all objects will
     be stored as separated files, Int32.max means all objects will be stored
     in sqlite. If you don't know your object's size, 20480(20KB) is a good choice.
     After first initialized you should not change this value of the specified path.
     
     Return A new cache object, or nil if an error occurs.
     
     - Parameters:
        - path: Full path of a directory in which the cache will write data.
     Once initialized you should not read and write to this directory.
        - threshold: Determine the object should store to sqlite or file system. The data store inline threshold in bytes.(Longinus use the default value: 20KB)
     Data < 20k -> SQLite. Data > 20k -> File
    */
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
        self.countLimit = Int32.max
        self.costLimit = Int32.max
        self.ageLimit = .never
        self.autoTrimInterval = 60
        self.shouldAutoTrim = true
        
        if shouldAutoTrim { autoTrim() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillBeTerminated), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    @objc private func appWillBeTerminated() {
        _ = ioLock.lock()
        storage = nil
        ioLock.unlock()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
    }
    
}

// MARK: CacheStandard
extension DiskCache {
    /*
     Check whether disk contains object with the specific key.
     */
    public func containsObject(key: Key) -> Bool {
        _ = ioLock.lock()
        defer { ioLock.unlock() }
        return storage?.containItemforKey(key: key) ?? false
    }
    
    /*
     Query the object from disk with the specific key.
     */
    public func query(key: Key) -> Value? {
        _ = ioLock.lock()
        let value = storage?.itemValueForKey(key: key)
        ioLock.unlock()
        return value
    }
    
    /*
     Save the object to disk with the specific key.
     */
    public func save(value: Value?, for key: Key) {
        guard let value = value else {
            remove(key: key)
            return
        }
        var filename: String? = nil
        if value.count > sizeThreshold {
            filename = key.lg.sha256
        }
        _ = ioLock.lock()
        storage?.save(key: key, value: value, filename: filename)
        ioLock.unlock()
    }
    
    /*
     Save the object to disk with the specific key with `dataWork` closure.
     */
    public func save(_ dataWork: @escaping () -> (Value, Int)?, forKey key: Key) {
        if let data = dataWork() {
            self.save(value: data.0, for: key)
        }
    }
    
    /*
     Remove object with the specific key.
     */
    public func remove(key: Key) {
        _ = ioLock.lock()
        storage?.remove(forKey: key)
        ioLock.unlock()
    }
    
    /*
     Empties the cache.
     This method may blocks the calling thread until file delete finished.
     */
    public func removeAll() {
        _ = ioLock.lock()
        storage?.remove(allItems: ())
        ioLock.unlock()
    }
}

// MARK: CacheAsyncStandard
extension DiskCache {
    
    /*
     Check whether disk contains object with specific key.
     This methods will call result handler from the background thead.
     */
    public func containsObject(key: Key, _ result: @escaping ((Key, Bool) -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            result(key, self.containsObject(key: key))
        }
    }
    
    /*
     Query the object from disk with the specific key.
     This methods will call result handler from the background thead.
     */
    public func query(key: Key, _ result: @escaping ((Key, Value?) -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            result(key, self.query(key: key))
        }
    }

    /*
     Save the object to disk with the specific key.
     This methods will call result handler from the background thead.
     */
    public func save(value: Value?, for key: Key, _ result: @escaping (() -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.save(value: value, for: key)
            result()
        }
    }
    
    /*
     Save the object to disk with the specific key with `dataWork` closure.
     This methods will call result handler from the background thead.
     */
    public func save(_ dataWork: @escaping () -> (Value, Int)?, forKey key: Key, result: @escaping (() -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.save(dataWork, forKey: key)
            result()
        }
    }
    
    /*
     Remove object with the specific key.
     This methods will call result handler from the background thead.
     */
    public func remove(key: Key, _ result: @escaping ((Key) -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.remove(key: key)
            result(key)
        }
    }
    
    /**
    Empties the cache.
    This method returns immediately and invoke the passed block in background queue
    when the operation finished.
    
    - Parameters:
        - result: A block which will be invoked in background queue when finished.
    */
    public func removeAll(_ result: @escaping (() -> Void)) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.removeAll()
            result()
        }
    }
}

extension DiskCache: AutoTrimable {
    
    /**
    Removes objects from the cache use LRU, until the `totalCount` is below the specified value.
    This method may blocks the calling thread until operation finished.
    
     - Parameters:
        - count: The total count allowed to remain after the cache has been trimmed.
    */
    
    func trimToCount(_ count: Int32) {
        _ = ioLock.lock()
        storage?.remove(toFitCount: count)
        ioLock.unlock()
    }
    
    /**
    Removes objects from the cache use LRU, until the `totalCost` is below the specified value.
    This method may blocks the calling thread until operation finished.
     
    - Parameters:
        - cost: The total cost allowed to remain after the cache has been trimmed.
    */
    func trimToCost(_ cost: Int32) {
        _ = ioLock.lock()
        storage?.remove(toFitSize: cost)
        ioLock.unlock()
    }
    
    /**
    Removes objects from the cache use LRU, until all expiry objects removed by the specified value.
    This method may blocks the calling thread until operation finished.
    
     - Parameters:
        - age: The age of the object.
    */
    func trimToAge(_ age: CacheAge) {
        _ = ioLock.lock()
        storage?.remove(earlierThan: age.timeInterval)
        ioLock.unlock()
    }
    
}
