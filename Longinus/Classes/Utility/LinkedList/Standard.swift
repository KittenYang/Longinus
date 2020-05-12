//
//  Standard.swift
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

// MARK: - Node and Link
protocol NodeStandard: class, Equatable, CustomStringConvertible {
    associatedtype Key where Key: Hashable
    associatedtype Value
    
    var key: Key { get }
    var value: Value { get }
    var pre: Self? { get }
    var next: Self? { get }
    init(key: Key, value: Value, pre: Self?, next: Self?)
}

extension NodeStandard {
    public var description: String {
        guard let next = next else { return "\(value)" }
        return "\(value) -> \(next)"
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key
    }
}

protocol LinkedNodeListIndexStandard: Comparable {
    associatedtype Node: NodeStandard
    var node: Node? { get }
    init(node: Node?)
}

extension LinkedNodeListIndexStandard {
    static public func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.node, rhs.node) {
        case let (left?, right?):
            return left.next === right.next
        case (nil, nil):
            return true
        default:
            return false
        }
    }
    
    static public func < (lhs: Self, rhs: Self) -> Bool {
        guard lhs != rhs else { return false }
        let nodes = sequence(first: lhs.node, next: { $0?.next })
        return nodes.contains(where: { $0 === rhs.node })
    }
}

protocol LinkedNodeListStandard: BidirectionalCollection where Index: LinkedNodeListIndexStandard {
    associatedtype Key: Hashable
    associatedtype Value
    
    subscript(key: Key) -> Value? { mutating get set }
    
    func contains(where predicate: (Key) throws -> Bool) rethrows -> Bool
    mutating func push(_ value: Value, for key: Key)
    mutating func remove(for key: Key) -> AnyLinkNode<Key, Value>?
    mutating func removeAll()
    mutating func removeTrail() -> AnyLinkNode<Key, Value>?
    mutating func value(for key: Key) -> Value?
}
