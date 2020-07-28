//
//  BBMemoryCache.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/29.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

private class BBMemoryCacheLinkedMapNode {
    // Weak var will slow down speed. So use strong var. Set all notes prev/next to nil when removing all nodes
    fileprivate var prev: BBMemoryCacheLinkedMapNode?
    fileprivate var next: BBMemoryCacheLinkedMapNode?
    
    fileprivate var key: String
    fileprivate var value: Any
    fileprivate var cost: Int
    fileprivate var lastAccessTime: TimeInterval
    
    fileprivate init(key: String, value: Any) {
        self.key = key
        self.value = value
        self.cost = 0
        self.lastAccessTime = CACurrentMediaTime()
    }
}

private class BBMemoryCacheLinkedMap {
    fileprivate var dic: [String : BBMemoryCacheLinkedMapNode]
    fileprivate var head: BBMemoryCacheLinkedMapNode?
    fileprivate var tail: BBMemoryCacheLinkedMapNode?
    fileprivate var totalCost: Int
    fileprivate var totalCount: Int
    
    deinit { breakRetainCycle() }
    
    init() {
        dic = [:]
        totalCost = 0
        totalCount = 0
    }
    
    fileprivate func bringNodeToHead(_ node: BBMemoryCacheLinkedMapNode) {
        if head === node { return }
        if tail === node {
            tail = node.prev
            tail?.next = nil
        } else {
            node.prev?.next = node.next
            node.next?.prev = node.prev
        }
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
    }
    
    fileprivate func insertNodeAtHead(_ node: BBMemoryCacheLinkedMapNode) {
        dic[node.key] = node
        if head == nil {
            head = node
            tail = node
        } else {
            node.next = head
            head?.prev = node
            head = node
        }
        totalCost += node.cost
        totalCount += 1
    }
    
    fileprivate func remove(_ node: BBMemoryCacheLinkedMapNode) {
        dic[node.key] = nil
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
        totalCost -= node.cost
        totalCount -= 1
    }
    
    fileprivate func removeAll() {
        dic.removeAll()
        breakRetainCycle()
        head = nil
        tail = nil
        totalCost = 0
        totalCount = 0
    }
    
    private func breakRetainCycle() {
        var node = head
        while let next = node?.next {
            next.prev = nil
            node = next
        }
    }
}

/// BBMemoryCache is a thread safe memory cache using least recently used algorithm
public class BBMemoryCache {
    private let linkedMap: BBMemoryCacheLinkedMap
    private var costLimit: Int
    private var countLimit: Int
    private var ageLimit: TimeInterval
    private var lock: pthread_mutex_t
    private var queue: DispatchQueue
    
    init() {
        linkedMap = BBMemoryCacheLinkedMap()
        costLimit = .max
        countLimit = .max
        ageLimit = .greatestFiniteMagnitude
        lock = pthread_mutex_t()
        pthread_mutex_init(&lock, nil)
        queue = DispatchQueue(label: "com.Kaibo.BBWebImage.MemoryCache.queue", qos: .background)
        
        NotificationCenter.default.addObserver(self, selector: #selector(clear), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clear), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        pthread_mutex_destroy(&lock)
    }
    
    /// Gets image with key
    ///
    /// - Parameter key: cache key
    /// - Returns: image in memory cache, or nil if no image found
    public func image(forKey key: String) -> UIImage? {
        pthread_mutex_lock(&lock)
        var value: UIImage?
        if let node = linkedMap.dic[key] {
            value = node.value as? UIImage
            node.lastAccessTime = CACurrentMediaTime()
            linkedMap.bringNodeToHead(node)
        }
        pthread_mutex_unlock(&lock)
        return value
    }
    
    /// Stores image with key and cost
    ///
    /// - Parameters:
    ///   - image: image to store
    ///   - key: cache key
    ///   - cost: cost of memory
    public func store(_ image: UIImage, forKey key: String, cost: Int = 0) {
        pthread_mutex_lock(&lock)
        let realCost: Int = cost > 0 ? cost : Int(image.size.width * image.size.height * image.scale)
        if let node = linkedMap.dic[key] {
            linkedMap.totalCost += realCost - node.cost
            node.value = image
            node.cost = realCost
            node.lastAccessTime = CACurrentMediaTime()
            linkedMap.bringNodeToHead(node)
        } else {
            let node = BBMemoryCacheLinkedMapNode(key: key, value: image)
            node.cost = realCost
            linkedMap.insertNodeAtHead(node)
            
            if linkedMap.totalCount > countLimit,
                let tail = linkedMap.tail {
                linkedMap.remove(tail)
            }
        }
        if linkedMap.totalCost > costLimit {
            queue.async { [weak self] in
                guard let self = self else { return }
                self.trim(toCost: self.costLimit)
            }
        }
        pthread_mutex_unlock(&lock)
    }
    
    /// Removes image with key
    ///
    /// - Parameter key: cache key
    public func removeImage(forKey key: String) {
        pthread_mutex_lock(&lock)
        if let node = linkedMap.dic[key] {
            linkedMap.remove(node)
        }
        pthread_mutex_unlock(&lock)
    }
    
    /// Removes all images
    @objc public func clear() {
        pthread_mutex_lock(&lock)
        linkedMap.removeAll()
        pthread_mutex_unlock(&lock)
    }
    
    public func setCostLimit(_ cost: Int) {
        pthread_mutex_lock(&lock)
        costLimit = cost
        queue.async { [weak self] in
            guard let self = self else { return }
            self.trim(toCost: cost)
        }
        pthread_mutex_unlock(&lock)
    }
    
    public func setCountLimit(_ count: Int) {
        pthread_mutex_lock(&lock)
        countLimit = count
        queue.async { [weak self] in
            guard let self = self else { return }
            self.trim(toCount: count)
        }
        pthread_mutex_unlock(&lock)
    }
    
    public func setAgeLimit(_ age: TimeInterval) {
        pthread_mutex_lock(&lock)
        ageLimit = age
        queue.async { [weak self] in
            guard let self = self else { return }
            self.trim(toAge: age)
        }
        pthread_mutex_unlock(&lock)
    }
    
    private func trim(toCost cost: Int) {
        pthread_mutex_lock(&lock)
        let unlock: () -> Void = { pthread_mutex_unlock(&self.lock) }
        if cost <= 0 {
            linkedMap.removeAll()
            return unlock()
        } else if linkedMap.totalCost <= cost {
            return unlock()
        }
        unlock()
        
        while true {
            if pthread_mutex_trylock(&lock) == 0 {
                if linkedMap.totalCost > cost,
                    let tail = linkedMap.tail {
                    linkedMap.remove(tail)
                } else {
                    return unlock()
                }
                unlock()
            } else {
                usleep(10 * 1000) // 10 ms
            }
        }
    }
    
    private func trim(toCount count: Int) {
        pthread_mutex_lock(&lock)
        let unlock: () -> Void = { pthread_mutex_unlock(&self.lock) }
        if count <= 0 {
            linkedMap.removeAll()
            return unlock()
        } else if linkedMap.totalCount <= count {
            return unlock()
        }
        unlock()
        
        while true {
            if pthread_mutex_trylock(&lock) == 0 {
                if linkedMap.totalCount > count,
                    let tail = linkedMap.tail {
                    linkedMap.remove(tail)
                } else {
                    return unlock()
                }
                unlock()
            } else {
                usleep(10 * 1000) // 10 ms
            }
        }
    }
    
    private func trim(toAge age: TimeInterval) {
        pthread_mutex_lock(&lock)
        let unlock: () -> Void = { pthread_mutex_unlock(&self.lock) }
        let now = CACurrentMediaTime()
        if age <= 0 {
            linkedMap.removeAll()
            return unlock()
        } else if linkedMap.tail == nil || now - linkedMap.tail!.lastAccessTime <= age {
            return unlock()
        }
        unlock()
        
        while true {
            if pthread_mutex_trylock(&lock) == 0 {
                if let tail = linkedMap.tail,
                    now - tail.lastAccessTime > age {
                    linkedMap.remove(tail)
                } else {
                    return unlock()
                }
                unlock()
            } else {
                usleep(10 * 1000) // 10 ms
            }
        }
    }
    
    private func trimRecursively() {
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }
            self.trim(toAge: self.ageLimit)
            self.trimRecursively()
        }
    }
}
