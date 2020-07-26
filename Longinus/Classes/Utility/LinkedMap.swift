//
//  LinkedMap.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/7/23.
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

class LinkedMapNode<Key: Hashable, Value> {
    // Weak var will slow down speed. So use strong var. Set all notes prev/next to nil when removing all nodes
    public var prev: LinkedMapNode?
    public var next: LinkedMapNode?
    
    public var key: Key
    public var value: Value?
    public var cost: Int
    public var lastAccessTime: TimeInterval
    
    public init(key: Key, value: Value?, cost: Int = 0) {
        self.key = key
        self.value = value
        self.cost = cost
        self.lastAccessTime = CACurrentMediaTime()
    }
}

class LinkedMap<Key: Hashable, Value> {
    public typealias Node = LinkedMapNode<Key, Value>
    
    public var head: Node?
    public var tail: Node?
    public var totalCost: Int
    public var totalCount: Int
    
    fileprivate var dic: [Key: Node]
    
    deinit { breakRetainCycle() }
    
    public init() {
        dic = [:]
        totalCost = 0
        totalCount = 0
    }
    
    public subscript(_ key: Key) -> Node? {
        get {
            return dic[key]
        }
        set {
            if let node = newValue {
                guard let old = dic[key] else {
                    insertNodeAtHead(node)
                    return
                }
                replaceNode(node: old, newNode: node)
            } else if let node = dic[key] {
                remove(node)
            }
        }
    }
    
    public func bringNodeToHead(_ node: Node) {
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
    
    public func insertNodeAtHead(_ node: Node) {
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
    
    public func remove(_ node: Node) {
        dic[node.key] = nil
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
        totalCost -= node.cost
        totalCount -= 1
    }
    
    public func replaceNode(node: Node, newNode: Node)  {
        dic[node.key] = newNode
        node.prev?.next = newNode
        node.next?.prev = newNode
        bringNodeToHead(newNode)
        
        totalCost += newNode.cost - node.cost
    }
    
    public func removeAll() {
        dic.removeAll()
        breakRetainCycle()
        head = nil
        tail = nil
        totalCost = 0
        totalCount = 0
    }
    
    @discardableResult
    public func removeTailNode() -> Node? {
        guard let tail = self.tail else {
            return nil
        }
        remove(tail)
        return tail
    }
    
    public func contains(_ key: Key) -> Bool {
        return dic.keys.contains(key)
    }
    
    private func breakRetainCycle() {
        var node = head
        while let next = node?.next {
            next.prev = nil
            node = next
        }
    }
}
