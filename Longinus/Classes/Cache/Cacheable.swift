//
//  Cacheable.swift
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
    

import UIKit

// MARK: Cache

public protocol MemoryCacheable: CacheStandard {
    mutating func save(value: Value, for key: Key, cost: Int)
}

public protocol DiskCacheable: CacheStandard, CacheAsyncStandard {
    init?(path: String, sizeThreshold threshold: Int) 
}

public protocol Cacheable {
    associatedtype M: CacheStandard
    associatedtype D: CacheStandard & CacheAsyncStandard where M.Key == D.Key, M.Value == D.Value
    init(memoryCache: M, diskCache: D)
}

public protocol CacheStandard {
    associatedtype Value
    associatedtype Key: Hashable
    func containsObject(key: Key) -> Bool
    mutating func query(key: Key) -> Value?
    mutating func save(value: Value, for key: Key)
    mutating func remove(key: Key)
    mutating func removeAll()
}

public protocol CacheAsyncStandard {
    associatedtype Value
    associatedtype Key: Hashable
    func containsObject(key: Key, _ result: @escaping ((_ key: Key, _ contain: Bool) -> Void))
    mutating func query(key: Key, _ result: @escaping ((_ key: Key, _ value: Value?) -> Void))
    mutating func save(value: Value, for key: Key, _ result: @escaping (()->Void))
    mutating func save(_ dataWork: @escaping () -> Data?, forKey key: String, result: @escaping (() -> Void))
    mutating func remove(key: Key, _ result: @escaping ((_ key: Key) -> Void))
    mutating func removeAll(_ result: @escaping (()->Void))
}

// MARK: - Trim
protocol AutoTrimable: class {
    var countLimit: Int { get }
    var costLimit: Int { get }
    var ageLimit: CacheAge { get }
    var autoTrimInterval: TimeInterval { get }
    var shouldAutoTrim: Bool { get set }
    
    func trimToAge(_ age: CacheAge)
    func trimToCost(_ cost: Int)
    func trimToCount(_ count: Int)
}

extension AutoTrimable {
    func autoTrim() {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + autoTrimInterval) {
            self.trimToAge(self.ageLimit)
            self.trimToCost(self.costLimit)
            self.trimToCount(self.countLimit)
            if self.shouldAutoTrim { self.autoTrim() }
        }
    }
}

public protocol CacheCostCalculable {
    var cacheCost: Int { get }
}

public enum CacheAge {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case expired
    
    var isExpired: Bool {
        return timeInterval <= 0
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .never: return .infinity
        case .seconds(let seconds): return seconds
        case .minutes(let minutes): return TimeInterval(TimeConstants.secondsInOneMinute) * TimeInterval(minutes)
        case .hours(let hours): return TimeInterval(TimeConstants.secondsInOneHour) * TimeInterval(hours)
        case .days(let days): return TimeInterval(TimeConstants.secondsInOneDay) * TimeInterval(days)
        case .expired: return -(.infinity)
        }
    }
    
    struct TimeConstants {
        static let secondsInOneMinute = 60
        static let secondsInOneHour = 3600
        static let minutesInOneHour = 60
        static let hoursInOneDay = 24
        static let secondsInOneDay = 86_400
    }
    
}

public struct ImageCacheType: OptionSet {
    public let rawValue: Int
    
    public static let none = ImageCacheType([])

    public static let memory = ImageCacheType(rawValue: 1 << 0)
    
    public static let disk = ImageCacheType(rawValue: 1 << 1)

    public static let all: ImageCacheType = [.memory, .disk]
    
    public init(rawValue: Int) { self.rawValue = rawValue }
}


public enum ImageCacheQueryCompletionResult {
    
    case none
    
    case memory(image: UIImage)

    case disk(data: Data)

    case all(image: UIImage, data: Data)
}

public protocol ImageCacheable: AnyObject {

    func image(forKey key: String, cacheType: ImageCacheType, completion: @escaping (ImageCacheQueryCompletionResult) -> Void)

    func diskDataExists(forKey key: String, completion: @escaping (Bool) -> Void)

    func store(_ image: UIImage?,
               data: Data?,
               forKey key: String,
               cacheType: ImageCacheType,
               completion: @escaping (() -> Void))


    func removeImage(forKey key: String, cacheType: ImageCacheType, completion: @escaping ((_ key: String) -> Void))

    func remove(_ type: ImageCacheType, completion: @escaping (() -> Void))
}
