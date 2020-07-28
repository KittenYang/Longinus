//
//  BBImageDownloadOperationQueue.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2/1/19.
//  Copyright © 2019 Kaibo Lu. All rights reserved.
//

import UIKit

private class BBImageDownloadLinkedMapNode {
    fileprivate weak var prev: BBImageDownloadLinkedMapNode?
    fileprivate weak var next: BBImageDownloadLinkedMapNode?
    fileprivate var key: URL
    fileprivate var value: BBImageDownloadOperation
    
    fileprivate init(key: URL, value: BBImageDownloadOperation) {
        self.key = key
        self.value = value
    }
}

private class BBImageDownloadLinkedMap {
    fileprivate var dic: [URL : BBImageDownloadLinkedMapNode]
    fileprivate var head: BBImageDownloadLinkedMapNode?
    fileprivate var tail: BBImageDownloadLinkedMapNode?
    
    init() { dic = [:] }
    
    fileprivate func enqueue(_ node: BBImageDownloadLinkedMapNode) {
        dic[node.key] = node
        if head == nil {
            head = node
            tail = node
        } else {
            tail?.next = node
            node.prev = tail
            tail = node
        }
    }
    
    fileprivate func dequeue() -> BBImageDownloadLinkedMapNode? {
        if let node = head {
            remove(node)
            return node
        }
        return nil
    }
    
    fileprivate func remove(_ node: BBImageDownloadLinkedMapNode) {
        dic[node.key] = nil
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
    }
}

class BBImageDownloadOperationQueue {
    private let waitingQueue: BBImageDownloadLinkedMap
    private let preloadWaitingQueue: BBImageDownloadLinkedMap
    var maxRunningCount: Int
    private(set) var currentRunningCount: Int
    
    init() {
        waitingQueue = BBImageDownloadLinkedMap()
        preloadWaitingQueue = BBImageDownloadLinkedMap()
        maxRunningCount = 1
        currentRunningCount = 0
    }
    
    func add(_ operation: BBImageDownloadOperation, preload: Bool) {
        if currentRunningCount < maxRunningCount {
            currentRunningCount += 1
            BBDispatchQueuePool.background.async { [weak self] in
                guard self != nil else { return }
                operation.start()
            }
        } else {
            let node = BBImageDownloadLinkedMapNode(key: operation.url, value: operation)
            if preload { preloadWaitingQueue.enqueue(node) }
            else { waitingQueue.enqueue(node) }
        }
    }
    
    func removeOperation(forKey key: URL) {
        if let node = waitingQueue.dic[key] {
            waitingQueue.remove(node)
        } else if let node = preloadWaitingQueue.dic[key] {
            preloadWaitingQueue.remove(node)
        } else if let next = waitingQueue.dequeue()?.value {
            BBDispatchQueuePool.background.async { [weak self] in
                guard self != nil else { return }
                next.start()
            }
        } else if let next = preloadWaitingQueue.dequeue()?.value {
            BBDispatchQueuePool.background.async { [weak self] in
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
