//
//  DispatchQueuePool.swift
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

/// DispatchQueuePool holds mutiple serial queues to prevent concurrent queue increasing thread count. Control thread count manually.
public class DispatchQueuePool {

    //userInteractive > default > unspecified > userInitiated > utility > background
    public static let userInteractive = DispatchQueuePool(label: "\(LonginusPrefixID).QueuePool.userInteractive", qos: .userInteractive)
    public static let `default` = DispatchQueuePool(label: "\(LonginusPrefixID).QueuePool.default", qos: .default)
    public static let userInitiated = DispatchQueuePool(label: "\(LonginusPrefixID).QueuePool.userInitiated", qos: .userInitiated)
    public static let utility = DispatchQueuePool(label: "\(LonginusPrefixID).QueuePool.utility", qos: .utility)
    public static let background = DispatchQueuePool(label: "\(LonginusPrefixID).QueuePool.background", qos: .background)
    
    private let queues: [DispatchQueue]//[OperationQueue]
    private var sentinel: Int32
    
    public var currentQueue: DispatchQueue {//OperationQueue {
        var currentIndex = OSAtomicIncrement32(&sentinel)
        if currentIndex < 0 { currentIndex = -currentIndex }
        return queues[Int(currentIndex) % queues.count]
    }
    
    public init(label: String, qos: DispatchQoS, queueCount: Int = 0) {
        let count = queueCount > 0 ? queueCount : min(16, max(1, ProcessInfo.processInfo.activeProcessorCount * 2))
        var pool: [DispatchQueue] = []
        for i in 0..<count {
            let queue = DispatchQueue(label: "\(label).\(i)", qos: qos, target: DispatchQueue.global(qos: qos.qosClass))
            pool.append(queue)
        }
        queues = pool
        sentinel = -1
    }
    
    public func async(work: @escaping () -> Void) {
        currentQueue.async(execute: work)
    }
    
}
