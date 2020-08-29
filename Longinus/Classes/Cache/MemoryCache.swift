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

/**
MemoryCache is a fast in-memory and thread-safe cache that stores key-value pairs.

* It uses LRU (least-recently-used) to remove objects.
* It can be controlled by cost, count and age.
* It can be configured to automatically evict objects when receive memory
  warning or app enter background.

The time of `Access Methods` in MemoryCache is typically in constant time (O(1)).
*/
public class MemoryCache<Key: Hashable, Value> {
    
    public typealias OperationBlock = (_ cache: MemoryCache<Key,Value>) -> Void
    
    /**
     Alias a node with Key-Value
     */
    typealias Node = LinkedMapNode<Key, Value>
    
    /**
     Alias a doubly linked list whick hold the cache data as `Node`
     */
    typealias LRU = LinkedMap<Key, Value>
    
    /**
     The underlying linked list whick store cache datas
     */
    fileprivate let lru = LRU()
    
    /**
     The lock to protect datas' safety
     */
    fileprivate let lock = UnfairLock()
    
    /**
     A serial queue to trim data every `autoTrimInterval` time.
     */
    fileprivate let trimQueue = DispatchQueue(label: "com.kittenyang.MemoryCache.memoryTrim", qos: .background)
    
    /**
     A concurrent queue to release LRU nodes if needed
     */
    fileprivate let releaseQueue = DispatchQueue.global(qos: .background)
    
    /**
     The number of objects in the cache
     */
    public var totalCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return lru.totalCount
    }
    
    /**
    Returns the total cost (in bytes) of objects in this cache.
    This method may blocks the calling thread until file read finished.
    
    return the total objects cost in bytes.
    */
    public var totalCost: Int {
        lock.lock()
        defer { lock.unlock() }
        return lru.totalCost
    }
    
    /**
     Determine whether should auto trim datas regularly
     */
    var shouldAutoTrim: Bool = false {
        didSet {
            if oldValue == shouldAutoTrim { return }
            if shouldAutoTrim {
                autoTrim()
            }
        }
    }
    
    /**
      The most recent accessed value of cache
      */
    public var first: Value? {
        return lru.head?.value
    }
    
    /**
      The lastest recent accessed value of cache
      */
    public var last: Value? {
        return lru.tail?.value
    }
    
    /**
    The maximum number of objects the cache should hold.
    
    The default value is Int32.max, which means no limit.
    This is not a strict limit—if the cache goes over the limit, some objects in the
    cache could be evicted later in backgound thread.
    */
    public var countLimit = Int32.max {
        didSet {
            setCountLimit(countLimit)
        }
    }
    
    /**
    The maximum total cost that the cache can hold before it starts evicting objects.
    
    The default value is Int32.max, which means no limit.
    This is not a strict limit—if the cache goes over the limit, some objects in the
    cache could be evicted later in backgound thread.
    */
    public var costLimit = Int32.max {
        didSet {
            setCostLimit(costLimit)
        }
    }
    
    /**
    The age of objects in cache.
    
    The default value is `.never`, which means no limit.
    This is not a strict limit—if an object goes over the limit, the object could
    be evicted later in backgound thread.
    */
    public var ageLimit: CacheAge = .never {
        didSet {
            setAgeLimit(ageLimit)
        }
    }
    
    /**
    The auto trim check time interval in seconds. Default is 5.0.
    
    The cache holds an internal timer to check whether the cache reaches
    its limits, and if the limit is reached, it begins to evict objects.
    */
    public var autoTrimInterval = TimeInterval(5) {
        didSet {
            self.shouldAutoTrim = self.autoTrimInterval > 0
        }
    }
    
    /**
    If `true`, the cache will remove all objects when the app receives a memory warning.
    The default value is `true`.
    */
    public var shouldremoveAllValuesOnMemoryWarning = true
    
    /**
    If `true`, The cache will remove all objects when the app enter background.
    The default value is `true`.
    */
    public var shouldremoveAllValuesWhenEnteringBackground = true
    
    /**
    A block to be executed when the app receives a memory warning.
    The default value is nil.
    */
    public var didReceiveMemoryWarningBlock: OperationBlock?
    
    /**
    A block to be executed when the app enter background.
    The default value is nil.
    */
    public var didEnterBackgroundBlock: OperationBlock?
    
    /**
    If `true`, the key-value pair will be released on main thread, otherwise on
    background thread. Default is false.
    
    You may set this value to `true` if the key-value object contains
    the instance which should be released in main thread (such as UIView/CALayer).
    */
    public var releaseOnMainThread = false
    
    
    /**
     The designed initialize methods.
     */
    public init(countLimit: Int32 = Int32.max,
         costLimit: Int32 = Int32.max,
         ageLimit: CacheAge = .never,
         autoTrimInterval: TimeInterval = 5) {

        self.countLimit = countLimit
        self.costLimit = costLimit
        self.ageLimit = ageLimit
        self.autoTrimInterval = autoTrimInterval
        
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache.appDidEnterBackgroundNotification(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache.appDidReceiveMemoryWarningNotification(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        lru.removeAll()
    }
    
    /**
     You can use subscript syntax to access value by the specific key.
     */
    subscript(_ key: Key) -> Value? {
        get {
            return query(key: key)
        }
    }
            
    /**
     The `didReceiveMemoryWarningNotification` notification selector
     */
    @objc fileprivate func appDidReceiveMemoryWarningNotification(_ notification: Notification) {
        didReceiveMemoryWarningBlock?(self)
        if shouldremoveAllValuesOnMemoryWarning {
            removeAll()
        }
    }
    
    /**
     The `didEnterBackgroundNotification` notification selector
     */
    @objc fileprivate func appDidEnterBackgroundNotification(_ notification: Notification) {
        didEnterBackgroundBlock?(self)
        if shouldremoveAllValuesWhenEnteringBackground {
            removeAll()
        }
    }
}


/**
 MemoryCacheable Implementation
 */
extension MemoryCache: MemoryCacheable {
    
    /**
    Returns a Boolean value that indicates whether a given key is in cache.
    
     - Parameters:
        - key: An object identifying the value.
    */
    public func containsObject(key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return lru.contains(key)
    }
    
    /**
    Returns the value associated with a given key. May be nil if no value is associated with key.
    
     - Parameters:
        - key: An object identifying the value.
    */
    public func query(key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let node = lru[key] else { return nil }
        let value = node.value
        node.lastAccessTime = Date().timeIntervalSince1970
        lru.bringNodeToHead(node)
        return value
    }
    
    /**
    Save the value of the specified key in the cache (0 cost).
     - Parameters:
        - object: The object to be stored in the cache. If nil, it calls `remove(key: key)`.
        - key: The key with which to associate the value.
    */
    public func save(value: Value?, for key: Key) {
        save(value: value, for: key, cost: 0)
    }
    
    /**
    Save the value of the specified key in the cache with the dataWork handler which return the Value(e.g. Data) and Value's cost
     - Parameters:
        - object: The object to be stored in the cache. If nil, it calls `remove(key: key)`.
        - key: The key with which to associate the value.
        - dataWork: A handler which return the Value(e.g. Data) and Value's cost
    */
    public func save(_ dataWork: @escaping () -> (Value, Int)?, forKey key: Key) {
        if let data = dataWork() {
            self.save(value: data.0, for: key, cost: data.1)
        }
    }
    
    /**
    Save the value of the specified key in the cache, and associates the key-value
    pair with the specified cost.
    
     - Parameters:
        - object: The object to be stored in the cache. If nil, it calls `remove(key: key)`.
        - key: The key with which to associate the value.
        - cost: The cost with which to associate the key-value pair.
    */
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

    
    /**
    Removes the value of the specified key in the cache.
    
     - Parameters:
        - key: The key identifying the value to be removed.
    */
    public func remove(key: Key) {
        lock.lock()
        defer { lock.unlock() }
        guard let node = lru[key] else { return }
        lru.remove(node)
    }
    
    /**
    Empties the cache immediately.
    */
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        lru.removeAll()
    }
    
    /**
     Remove the lastest used value.
     */
    private func removeLast() {
        lock.lock()
        self.lru.removeTailNode()
        lock.unlock()
    }
    
    //MARK: Private methods
    
    /**
     Set the costLimit. Also will trigger `trimToCost` methods.
     */
    private func setCostLimit(_ cost: Int32) {
        lock.lock()
        self.trimQueue.async { [weak self] in
            self?.trimToCost(cost)
        }
        lock.unlock()
    }
    
    /**
     Set the countLimit. Also will trigger `trimToCount` methods.
     */
    private func setCountLimit(_ count: Int32) {
        lock.lock()
        self.trimQueue.async { [weak self] in
            self?.trimToCount(count)
        }
        lock.unlock()
    }
    
    /**
     Set the ageLimit. Also will trigger `trimToAge` methods.
     */
    private func setAgeLimit(_ age: CacheAge) {
        lock.lock()
        self.trimQueue.async { [weak self] in
            self?.trimToAge(age)
        }
        lock.unlock()
    }
    
}

extension MemoryCache: AutoTrimable {

    /**
    Removes objects from the cache with LRU, until the `totalCount` is below or equal to
    the specified value.
     
     - Parameters:
        - count: The total count allowed to remain after the cache has been trimmed.
    */
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
            if lock.trylock() {
                if lru.totalCount > count,
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10 * 1000) //10 ms. if trylock failed, reduce `do-while` times to prevent cpu wastage
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : releaseQueue
            q.async {
                buffer.removeAll()
            }
        }
    }
        
    /**
    Removes objects from the cache use LRU, until the `totalCost` is or equal to specified value.
    This method may blocks the calling thread until operation finished.
     
    - Parameters:
        - cost: The total cost allowed to remain after the cache has been trimmed.
    */
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
            if lock.trylock() {
                if lru.totalCost >= cost,
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10 * 1000) //10 ms. if trylock failed, reduce `do-while` times to prevent cpu wastage
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : releaseQueue
            q.async {
                buffer.removeAll()
            }
        }
        
    }
    
    /**
    Removes objects from the cache use LRU, until all expiry objects removed by the specified value.
    This method may blocks the calling thread until operation finished.
    
     - Parameters:
        - age: The age of the object.
    */
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
            if lock.trylock() {
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
                usleep(10 * 1000) //10 ms. If trylock failed, reduce `do-while` times to prevent cpu wastage
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

