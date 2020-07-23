//
//  ImageDownloadOperationQueue.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/14.
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

private class ImageDownloadLinkedMapNode {
    fileprivate weak var prev: ImageDownloadLinkedMapNode?
    fileprivate weak var next: ImageDownloadLinkedMapNode?
    fileprivate var key: URL
    fileprivate var value: ImageDownloadOperateable
    
    fileprivate init(key: URL, value: ImageDownloadOperateable) {
        self.key = key
        self.value = value
    }
}

private class ImageDownloadLinkedMap {
    private var lock: Mutex
    fileprivate var dic: [URL : ImageDownloadLinkedMapNode]
    fileprivate var head: ImageDownloadLinkedMapNode?
    fileprivate var tail: ImageDownloadLinkedMapNode?
    
    init() {
        dic = [:]
        lock = Mutex()
    }
    
    fileprivate func enqueue(_ node: ImageDownloadLinkedMapNode) {
        lock.lock()
        dic[node.key] = node
        if head == nil {
            head = node
            tail = node
        } else {
            tail?.next = node
            node.prev = tail
            tail = node
        }
        lock.unlock()
    }
    
    fileprivate func dequeue() -> ImageDownloadLinkedMapNode? {
        if let node = head {
            remove(node)
            return node
        }
        return nil
    }
    
    fileprivate func remove(_ node: ImageDownloadLinkedMapNode) {
        lock.lock()
        dic[node.key] = nil
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
        lock.unlock()
    }
}

class ImageDownloadOperationQueue {
    private let waitingQueue: ImageDownloadLinkedMap
    private let preloadWaitingQueue: ImageDownloadLinkedMap
    var maxRunningCount: Int
    private(set) var currentRunningCount: Int
    
    init() {
        waitingQueue = ImageDownloadLinkedMap()
        preloadWaitingQueue = ImageDownloadLinkedMap()
        maxRunningCount = DispatchQueuePool.fitableMaxQueueCount
        currentRunningCount = 0
    }
    
    func add(_ operation: ImageDownloadOperateable, preload: Bool) {
        if currentRunningCount < maxRunningCount {
            currentRunningCount += 1
            DispatchQueuePool.background.async { [weak self] in
                guard self != nil else { return }
                operation.start()
            }
        } else {
            let node = ImageDownloadLinkedMapNode(key: operation.url, value: operation)
            if preload { preloadWaitingQueue.enqueue(node) }
            else { waitingQueue.enqueue(node) }
        }
    }
    
    /// run next operation
    func removeOperation(forKey key: URL) {
        if let node = waitingQueue.dic[key] {
            waitingQueue.remove(node)
        } else if let node = preloadWaitingQueue.dic[key] {
            preloadWaitingQueue.remove(node)
        } else if let next = waitingQueue.dequeue()?.value {
            DispatchQueuePool.background.async { [weak self] in
                guard self != nil else { return }
                next.start()
            }
        } else if let next = preloadWaitingQueue.dequeue()?.value {
            DispatchQueuePool.background.async { [weak self] in
                guard self != nil else { return }
                next.start()
            }
        } else {
            currentRunningCount -= 1
            assert(currentRunningCount >= 0, "currentRunningCount must >= 0")
        }
    }
    
    func upgradePreloadOperation(for key: URL) {
        if let node = preloadWaitingQueue.dic[key] {
            preloadWaitingQueue.remove(node)
            node.prev = nil
            node.next = nil
            waitingQueue.enqueue(node)
        }
    }
}
