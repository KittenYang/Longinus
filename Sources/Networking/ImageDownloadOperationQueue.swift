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

/*
 A FIFO linked list
 */
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

/**
 A customized Opeation Queue used linked list to handle web image download operation
 
 */
class ImageDownloadOperationQueue {
    /**
     The max running count of web image loading.
     Default value is 2x current device's active processor count.
     */
    var maxRunningCount: Int
    
    private let waitingQueue: ImageDownloadLinkedMap
    private let preloadWaitingQueue: ImageDownloadLinkedMap
    private(set) var currentRunningCount: Int
    
    init() {
        waitingQueue = ImageDownloadLinkedMap()
        preloadWaitingQueue = ImageDownloadLinkedMap()
        maxRunningCount = DispatchQueuePool.fitableMaxQueueCount
        currentRunningCount = 0
    }
    
    /**
     If the `currentRunningCount` less than `maxRunningCount`, the adding operation will start immediately without adding to the waiting queue. When this opertation completed, it will call `removeOperation` to dequeue next head operation.
     Otherwise, it will be added to the FIFO serial queue waiting for start.
     The web image download operation will run in background thread.
     */
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
    
    /**
     This methods will remove the operation node by the key if hitted.
     Typically, it will not hit first and second if-conditions as the running opeations will not exist in waitingQueue or preloadWaitingQueue.
     It mostly will find the next operation to start.
     Firstly, it will find the waiting operation in waitingQueue.
     If there is no more oprations in waitingQueue, it will find the operation in preloadWaitingQueue.
     */
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
    
    /**
     Take the operation in preload queue to waiting queue for higher priority.
     */
    func upgradePreloadOperation(for key: URL) {
        if let node = preloadWaitingQueue.dic[key] {
            preloadWaitingQueue.remove(node)
            node.prev = nil
            node.next = nil
            waitingQueue.enqueue(node)
        }
    }
}
