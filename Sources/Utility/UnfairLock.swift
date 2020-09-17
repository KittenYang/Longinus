//
//  UnfairLock.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/7/29.
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

@available(iOS 10.0, *)
public final class UnfairLock {
  
  @usableFromInline
  internal private(set) var _lock: UnsafeMutablePointer<os_unfair_lock>
  
  public init() {
    _lock = .allocate(capacity: 1)
    _lock.initialize(to: os_unfair_lock())
  }
  
  deinit { _lock.deallocate() }
}

@available(iOS 10.0, *)
extension UnfairLock {
  
  @inlinable
  public func lock() { os_unfair_lock_lock(_lock) }
  
  @inlinable
  public func unlock() { os_unfair_lock_unlock(_lock) }
}

@available(iOS 10.0, *)
extension UnfairLock {
  
  @inlinable
  public func trylock() -> Bool { os_unfair_lock_trylock(_lock) }
}

@available(iOS 10.0, *)
extension UnfairLock {
  
  @inlinable
  public func trySync<R>(_ block: () throws -> R) rethrows -> R? {
    guard trylock() else  { return nil }
    defer { unlock() }
    return try block()
  }
  
  @inlinable
  public func sync<R>(_ block: () throws -> R) rethrows -> R {
    lock()
    defer { unlock() }
    return try block()
  }
}

@available(iOS 10.0, *)
extension UnfairLock {
  
  public enum Predicate {
    
    case onThreadOwner
    case notOnThreadOwner
  }
}

@available(iOS 10.0, *)
extension UnfairLock {
  
  @inlinable
  public func precondition(condition: Predicate) {
    if condition == .onThreadOwner {
      os_unfair_lock_assert_owner(_lock)
    } else {
      os_unfair_lock_assert_not_owner(_lock)
    }
  }
    
}
