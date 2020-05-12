//
//  LinkedList.swift
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

public class AnyLinkNode<K: Hashable, V> {
    public typealias Key = K
    public typealias Value = V
    
    public private(set) var key: Key
    public private(set) var value: Value
    
    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
    
    deinit {
        print("----- ☠️ AnyLinkNode Deinit -------")
    }
}

final class LinkNode<K: Hashable, V>: AnyLinkNode<K, V>, NodeStandard {
    public fileprivate(set) weak var pre: LinkNode?
    public fileprivate(set) weak var next: LinkNode?
    
    public init(key: Key, value: Value, pre: LinkNode? = nil, next: LinkNode? = nil) {
        self.pre = pre
        self.next = next
        super.init(key: key, value: value)
    }
}

public struct LinkedNodeListIndex<K: Hashable, V>: LinkedNodeListIndexStandard {
    var node: LinkNode<K, V>?
    init(node: LinkNode<K, V>?) {
        self.node = node
    }
}

public struct LinkedList<K: Hashable, V>: LinkedNodeListStandard, CustomStringConvertible {
    public typealias Key = K
    public typealias Value = V
    public typealias Node = AnyLinkNode<K, V>
    public typealias Index = LinkedNodeListIndex<K, V>
    private typealias RealNode = LinkNode<K, V>
    
    private var head: RealNode?
    private var trail: RealNode?
    
    private var dictContainer = Dictionary<K, RealNode>()
    
    public init() {}
    
    public subscript(key: K) -> V? {
        mutating get {
            return value(for: key)
        }
        
        set {
            if let value = newValue {
                push(value, for: key)
            } else {
                remove(for: key)
            }
        }
    }
    
    public func contains(where predicate: (Key) throws -> Bool) rethrows -> Bool {
        do {
            for key in dictContainer.keys where try predicate(key) {
                return true
            }
            
            return false
        } catch {
            return false
        }
    }
}

extension LinkedList: BidirectionalCollection {
    public var startIndex: Index {
        return Index(node: head)
    }

    public var endIndex: Index {
        return Index(node: trail?.next)
    }

    public func index(before i: Index) -> Index {
        if i == endIndex { return Index(node: trail) }
        return Index(node: i.node?.pre)
    }

    public func index(after i: Index) -> Index {
        return Index(node: i.node?.next)
    }

    public subscript(position: Index) -> Value {
        return position.node!.value
    }
}


// MARK: - add
extension LinkedList {
    // head-first insertion
    public mutating func push(_ value: Value, for key: Key) {
        if let node = dictContainer[key] {
            bringNodeToHead(node)
        } else {
            let node = RealNode(key: key, value: value, next: head)
            dictContainer[key] = node
            head?.pre = node
            head = node
            if trail == nil {
                trail = head
            }
        }
    }
    
    private mutating func push(_ node: Node) {
        push(node.value, for: node.key)
    }
}

// MARK: - remove
extension LinkedList {
    @discardableResult
    public mutating func remove(for key: Key) -> Node? {
        if let node = dictContainer.removeValue(forKey: key) {
            if node == head {
                node.next?.pre = nil
                head = node.next
                node.next = nil
            } else if node == trail {
                node.pre?.next = nil
                trail = node.pre
                node.pre = nil
            } else {
                node.pre?.next = node.next
                node.next?.pre = node.pre
            }
            
            return node
        }
        
        return nil
    }
    
    @discardableResult
    private mutating func remove(_ node: Node) -> Node? {
        return remove(for: node.key)
    }
    
    public mutating func removeAll() {
        head = nil
        trail = nil
        dictContainer.removeAll()
    }
    
    @discardableResult
    public mutating func removeTrail() -> Node? {
        let removedNode = trail
        if trail == head {
            trail = nil
            head = nil
        } else {
            trail = trail?.pre
            trail?.next?.pre = nil
            trail?.next = nil
        }
        
        if let removedNode = removedNode {
            return dictContainer.removeValue(forKey: removedNode.key)
        }
        
        return nil
    }
}

// MARK: - query
extension LinkedList {
    public mutating func value(for key: Key) -> V? {
        if let node = dictContainer[key] {
            bringNodeToHead(node)
            return node.value
        }
        
        return nil
    }
}

// MARK: - update
extension LinkedList {
    private mutating func bringNodeToHead(_ node: RealNode) {
        if node == head { return }
        
        if node == trail {
            trail = trail?.pre
            trail?.next = nil
        } else {
            node.next?.pre = node.pre
            node.pre?.next = node.next
        }
        
        node.next = head
        head?.pre = node
        head = node
    }
}

extension LinkedList {
    public var description: String {
        return head?.description ?? "is empty"
    }
}
