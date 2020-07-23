//
//  MemoryCache.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/11.
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

public class MemoryCache<Key: Hashable, Value> {
    
    public typealias OperationBlock = (_ cache: MemoryCache<Key,Value>) -> Void
    typealias Node = LinkedMapNode<Key, Value>
    typealias LRU = LinkedMap<Key, Value>
    
    fileprivate let lru = LRU()
    fileprivate let lock = Mutex()
    fileprivate let trimQueue = DispatchQueue(label: LonginusPrefixID + ".memoryTrim", qos: .background)
    fileprivate let releaseQueue = DispatchQueue.global(qos: .background)
    
    public var totalCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return lru.totalCount
    }
    public var totalCost: Int {
        lock.lock()
        defer { lock.unlock() }
        return lru.totalCost
    }
    var shouldAutoTrim: Bool {
        didSet {
            if oldValue == shouldAutoTrim { return }
            if shouldAutoTrim {
                autoTrim()
            }
        }
    }
    
    public var first: Value? {
        return lru.head?.value
    }
    
    public var last: Value? {
        return lru.tail?.value
    }
    
    public var name: String?
    public var countLimit = Int32.max
    public var costLimit = Int32.max
    public var ageLimit: CacheAge = .never
    public var autoTrimInterval = TimeInterval(5)
    public var shouldremoveAllValuesOnMemoryWarning = true
    public var shouldremoveAllValuesWhenEnteringBackground = true
    
    public var didReceiveMemoryWarningBlock: OperationBlock?
    public var didEnterBackgroundBlock: OperationBlock?
    
    public var releaseOnMainThread = false
    public var releaseAsynchronously = false
    
    // MARK: - application lifetime observers
    
    public init(countLimit: Int32 = Int32.max,
         costLimit: Int32 = Int32.max,
         ageLimit: CacheAge = .never,
         autoTrimInterval: TimeInterval = 5) {

        self.countLimit = countLimit
        self.costLimit = costLimit
        self.ageLimit = ageLimit
        self.autoTrimInterval = autoTrimInterval
        self.shouldAutoTrim = self.autoTrimInterval > 0
        
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache.appDidEnterBackgroundNotification(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache.appDidReceiveMemoryWarningNotification(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #endif
        
        if shouldAutoTrim { autoTrim() }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        lru.removeAll()
    }
        
    subscript(_ key: Key) -> Value? {
        get {
            return query(key: key)
        }
    }
            
    // MARK: - system notifications
    @objc fileprivate func appDidReceiveMemoryWarningNotification(_ notification: Notification) {
        didReceiveMemoryWarningBlock?(self)
        if shouldremoveAllValuesOnMemoryWarning {
            removeAll()
        }
    }
    
    @objc fileprivate func appDidEnterBackgroundNotification(_ notification: Notification) {
        didEnterBackgroundBlock?(self)
        if shouldremoveAllValuesWhenEnteringBackground {
            removeAll()
        }
    }
}



extension MemoryCache: MemoryCacheable {
    public func containsObject(key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return lru.contains(key)
    }
    
    public func query(key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let node = lru[key] else { return nil }
        let value = node.value
        node.lastAccessTime = Date().timeIntervalSince1970
        lru.bringNodeToHead(node)
        return value
    }
    
    // MARK: - save
    public func save(value: Value?, for key: Key) {
        save(value: value, for: key, cost: 0)
    }
    
    public func save(_ dataWork: @escaping () -> (Value, Int)?, forKey key: Key) {
        if let data = dataWork() {
            self.save(value: data.0, for: key, cost: data.1)
        }
    }
    
    public func save(value: Value?, for key: Key, cost: Int = 0) {
        guard value != nil else {
            remove(key: key)
            return
        }
        lock.lock()
        if let node = lru[key] {
            lru.totalCost += cost - node.cost
            node.value = value
            node.cost = cost
            node.lastAccessTime = CACurrentMediaTime()
            lru.bringNodeToHead(node)
        } else {
            let node = Node(key: key, value: value)
            node.cost = cost
            lru.insertNodeAtHead(node)
            
            if lru.totalCount > countLimit,
                let tail = lru.tail {
                lru.remove(tail)
            }
        }
        if lru.totalCost > costLimit {
            trimQueue.async { [weak self] in
                guard let self = self else { return }
                self.trimToCost(self.costLimit)
            }
        }
        lock.unlock()
    }

    
    // MARK: - remove
    public func remove(key: Key) {
        lock.lock()
        defer { lock.unlock() }
        guard let node = lru[key] else { return }
        lru.remove(node)
    }
    
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        lru.removeAll()
    }
    
    public func setCostLimit(_ cost: Int32) {
        lock.lock()
        self.costLimit = cost
        self.trimQueue.async { [weak self] in
            self?.trimToCost(cost)
        }
        lock.unlock()
    }
    
    public func setCountLimit(_ count: Int32) {
        lock.lock()
        self.countLimit = count
        self.trimQueue.async { [weak self] in
            self?.trimToCount(count)
        }
        lock.unlock()
    }
    
    public func setAgeLimit(_ age: CacheAge) {
        lock.lock()
        self.ageLimit = age
        self.trimQueue.async { [weak self] in
            self?.trimToAge(age)
        }
        lock.unlock()
    }
    
    private func removeLast() {
        lock.lock()
        self.lru.removeTailNode()
        lock.unlock()
    }
}

extension MemoryCache: AutoTrimable {
    
    public func trimToCount(_ count: Int32) {
        guard count > 0 else {
            removeAll()
            return
        }
        lock.lock()
        guard lru.totalCount > count else {
            lock.unlock()
            return
        }
        lock.unlock()
        var buffer = [Node]()
        var finish = false
        while !finish {
            if lock.trylock() == 0 {
                if lru.totalCount > count,
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10 * 1000)
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : releaseQueue
            q.async {
                buffer.removeAll()
            }
        }
    }
    
    public func trimToCost(_ cost: Int32) {
        guard cost > 0 else {
            removeAll()
            return
        }
        lock.lock()
        guard lru.totalCost > cost else {
            lock.unlock()
            return
        }
        lock.unlock()
        var buffer = [Node]()
        var finish = false
        while !finish {
            if lock.trylock() == 0 {
                if lru.totalCost >= cost,
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10 * 1000)
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : releaseQueue
            q.async {
                buffer.removeAll()
            }
        }
        
    }
    
    public func trimToAge(_ age: CacheAge) {
        if age.timeInterval == Int32.max { return }
        guard age.timeInterval > 0 else {
            removeAll()
            return
        }
        let now = Date().timeIntervalSince1970
        lock.lock()
        guard let tail = lru.tail else {
            lock.unlock()
            return
        }
        if now - tail.lastAccessTime <= TimeInterval(age.timeInterval) {
            lock.unlock()
            return
        }
        lock.unlock()
        var buffer = [Node]()
        var finish = false
        while !finish {
            if lock.trylock() == 0 {
                guard let tail = lru.tail else {
                    lock.unlock()
                    return
                }
                if now - tail.lastAccessTime > TimeInterval(age.timeInterval),
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10 * 1000)
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : releaseQueue
            q.async {
                buffer.removeAll()
            }
        }
    }
}

