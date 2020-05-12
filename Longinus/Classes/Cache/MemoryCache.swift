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

public class MemoryCache<Key: Hashable, Value: Codable> {
    
    let releaseQueue = DispatchQueue.global(qos: .utility)
    
    private let lock: Mutex = Mutex()
    private var lru = LinkedList<Key, Value>()
    private var trimDict = [Key:TrimNode]()
    private let queue = DispatchQueue(label: "com.kittenyang.cache.memory")
    
    private(set) var countLimit: Int
    private(set) var costLimit: Int
    private(set) var ageLimit: CacheAge
    private(set) var autoTrimInterval: TimeInterval
    
    public private(set) var totalCost: Int = 0
    public var totalCount: Int {
        return lock.locked { () -> (Int) in
            return lru.count
        }
    }
    public var shouldRemoveAllObjectsOnMemoryWarning: Bool = true
    public var shouldRemoveAllObjectsWhenEnteringBackground: Bool = true
    public var didReceiveMemoryWarningBlock: ((MemoryCache<Key,Value>)->Void)?
    public var didEnterBackgroundBlock: ((MemoryCache<Key,Value>)->Void)?
    public var releaseOnMainThread: Bool = false
    public var releaseAsynchronously: Bool = true
    
    var shouldAutoTrim: Bool {
        didSet {
            if oldValue == shouldAutoTrim { return }
            if shouldAutoTrim {
                autoTrim()
            }
        }
    }
    
    public var first: Value? {
        return lru.first
    }
    
    public var last: Value? {
        return lru.last
    }
    
    public init(countLimit: Int = Int.max, costLimit: Int = Int.max, ageLimit: CacheAge = .never, autoTrimInterval: TimeInterval = 5) {
        self.totalCost = 0
        self.countLimit = countLimit
        self.costLimit = costLimit
        self.ageLimit = ageLimit
        self.autoTrimInterval = autoTrimInterval
        self.shouldAutoTrim = self.autoTrimInterval > 0
        
        if shouldAutoTrim { autoTrim() }
    }

}

extension MemoryCache: MemoryCacheable {
    public func containsObject(key: Key) -> Bool {
        return lru.contains(where: { $0 == key })
    }
    
    public func query(key: Key) -> Value? {
        return lock.locked { () -> (Value?) in
            trimDict[key]?.updateAge()
            return lru.value(for: key)
        }
    }
    
    // MARK: - save
    public func save(value: Value, for key: Key) {
        save(value: value, for: key, cost: 0)
    }
    
    public func save(value: Value, for key: Key, cost: Int = 0) {
        lock.locked {
            trimDict[key] = TrimNode(cost: cost)
            totalCost += cost
            
            lru.push(value, for: key)
            
            if totalCost > costLimit {
                queue.async { [weak self] in
                    guard let self = self else { return }
                    self.trimToCost(self.costLimit)
                }
            }
            if totalCount > countLimit {
                let trailNode = lru.removeTrail()
                if releaseAsynchronously {
                    let queue = releaseOnMainThread ? DispatchQueue.main : releaseQueue
                    queue.async {
                        let _ = trailNode?.key //hold and release in queue
                    }
                } else if (releaseOnMainThread && pthread_main_np() == 0) {
                    DispatchQueue.main.async {
                        let _ = trailNode?.key //hold and release in queue
                    }
                }
            }
        }
    }
    
    // MARK: - remove
    public func remove(key: Key) {
        lock.locked {
            if let node = trimDict[key] {
                totalCost -= node.cost
                lru.remove(for: key)
                trimDict.removeValue(forKey: key)
                if releaseAsynchronously {
                    let queue = releaseOnMainThread ? DispatchQueue.main : releaseQueue
                    queue.async {
                        let _ = node //hold and release in queue
                    }
                } else if (releaseOnMainThread && pthread_main_np() == 0) {
                    DispatchQueue.main.async {
                        let _ = node //hold and release in queue
                    }
                }
            }
        }
    }
    
    public func removeAll() {
        lock.locked {
            trimDict.removeAll()
            totalCost = 0
            lru.removeAll()
        }
    }
    
    public func setCostLimit(_ cost: Int) {
        lock.locked {
            costLimit = cost
            queue.async { [weak self] in
                guard let self = self else { return }
                self.trimToCost(cost)
            }
        }
    }
    
    public func setCountLimit(_ count: Int) {
        lock.locked {
            countLimit = count
            queue.async { [weak self] in
                guard let self = self else { return }
                self.trimToCount(count)
            }
        }
    }
    
    public func setAgeLimit(_ age: CacheAge) {
        lock.locked {
            ageLimit = age
            queue.async { [weak self] in
                guard let self = self else { return }
                self.trimToAge(age)
            }
        }
    }
    
    private func removeLast() {
        lock.locked {
            if let key = lru.removeTrail()?.key, let cost = trimDict.removeValue(forKey: key)?.cost {
                totalCost -= cost
            }
        }
    }
}

extension MemoryCache: AutoTrimable {
    public func trimToCount(_ countLimit: Int) {
        lock.locked {
            if countLimit <= 0 {
                self.removeAll()
                return
            } else if lru.count <= countLimit {
                return
            }
        }
        
        while true {
            if self.lock.tryLock() == 0 {
                if lru.count > countLimit,
                    !lru.isEmpty {
                    self.removeLast()
                } else {
                    return self.lock.unlock()
                }
                self.lock.unlock()
            } else {
                usleep(10 * 1000) // 10 ms
            }
        }
    }
    
    public func trimToCost(_ costLimit: Int) {
        lock.locked {
            if costLimit <= 0 {
                self.removeAll()
                return
            } else if totalCost <= costLimit {
                return
            }
        }
        
        while true {
            if self.lock.tryLock() == 0 {
                if totalCost > costLimit, totalCost > 0 {
                    self.removeLast()
                } else {
                    return self.lock.unlock()
                }
                self.lock.unlock()
            } else {
                usleep(10 * 1000) // 10 ms
            }
        }
    }
    
    public func trimToAge(_ ageLimit: CacheAge) {
        self.lock.locked {
            if ageLimit.timeInterval <= 0 {
                self.removeAll()
                return
            }
        }
        let now = Date().timeIntervalSince1970
        while true {
            if self.lock.tryLock() == 0 {
                if let lastNodeKey = lru.index(before: lru.endIndex).node?.key,
                    let lastTrimNode = trimDict[lastNodeKey],
                    now - lastTrimNode.age > ageLimit.timeInterval {
                    self.removeLast()
                } else {
                    return self.lock.unlock()
                }
                self.lock.unlock()
            } else {
                usleep(10 * 1000) // 10 ms
            }
        }
    }
}

extension MemoryCache {
    private struct TrimNode: Hashable {
        private(set) var cost: Int
        private(set) var age: TimeInterval = Date().timeIntervalSince1970
        
        mutating func updateAge() {
            self.age = Date().timeIntervalSince1970
        }
        
        init(cost: Int) {
            self.cost = cost
        }
    }
}

extension MemoryCache: CustomStringConvertible {
    public var description: String {
        return lru.description
    }
}

