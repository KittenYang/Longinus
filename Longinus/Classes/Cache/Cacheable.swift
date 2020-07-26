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

/*
 Represents memory cache ablity.
 */
public protocol MemoryCacheable: CacheStandard {
    mutating func save(value: Value?, for key: Key, cost: Int)
}

/*
Represents disk cache ablity.
*/
public protocol DiskCacheable: CacheStandard, CacheAsyncStandard {
    init?(path: String, sizeThreshold threshold: Int32) 
}

/*
Represents a cache which has both disk and memory cache ablity.
*/
public protocol Cacheable {
    associatedtype M: CacheStandard
    associatedtype D: CacheStandard & CacheAsyncStandard where M.Key == D.Key, M.Value == D.Value
    init(memoryCache: M, diskCache: D)
}

/*
Represents synchronous cache ablity standard.
*/
public protocol CacheStandard {
    associatedtype Value
    associatedtype Key: Hashable
    func containsObject(key: Key) -> Bool
    mutating func query(key: Key) -> Value?
    mutating func save(value: Value?, for key: Key)
    mutating func save(_ dataWork: @escaping () -> (Value, Int)?, forKey key: Key)
    mutating func remove(key: Key)
    mutating func removeAll()
}

/*
Represents asynchronous cache ablity standard.
*/
public protocol CacheAsyncStandard {
    associatedtype Value
    associatedtype Key: Hashable
    func containsObject(key: Key, _ result: @escaping ((_ key: Key, _ contain: Bool) -> Void))
    mutating func query(key: Key, _ result: @escaping ((_ key: Key, _ value: Value?) -> Void))
    mutating func save(value: Value?, for key: Key, _ result: @escaping (()->Void))
    mutating func save(_ dataWork: @escaping () -> (Value, Int)?, forKey key: Key, result: @escaping (() -> Void))
    mutating func remove(key: Key, _ result: @escaping ((_ key: Key) -> Void))
    mutating func removeAll(_ result: @escaping (()->Void))
}

/*
Represents cache trimable ablity.
*/
protocol AutoTrimable: class {
    var countLimit: Int32 { get }
    var costLimit: Int32 { get }
    var ageLimit: CacheAge { get }
    var autoTrimInterval: TimeInterval { get }
    var shouldAutoTrim: Bool { get set }
    
    func trimToAge(_ age: CacheAge)
    func trimToCost(_ cost: Int32)
    func trimToCount(_ count: Int32)
}

/*
Default method for auto trim which runs in concurrent background queue. This method repeats every `autoTrimInterval` seconds.
*/
extension AutoTrimable {
    func autoTrim() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + autoTrimInterval) {
            self.trimToAge(self.ageLimit)
            self.trimToCost(self.costLimit)
            self.trimToCount(self.countLimit)
            if self.shouldAutoTrim { self.autoTrim() }
        }
    }
}

/*
 Represents types which cost in memory can be calculated.
*/
public protocol CacheCostCalculable {
    var cacheCost: Int64 { get }
}

/*
 Represents the expiration strategy used in storage.
 
 - never: The item never expires.
 - seconds: The item expires after a time duration of given seconds from now.
 - minutes: The item expires after a time duration of given minutes from now.
 - hours: The item expires after a time duration of given hours from now.
 - days: The item expires after a time duration of given days from now.
 - expired: Indicates the item is already expired. Use this to skip cache.
 */
public enum CacheAge {
    /// The item never expires.
    case never
    /// The item expires after a time duration of given seconds from now.
    case seconds(Int32)
    /// The item expires after a time duration of given minutes from now.
    case minutes(Int32)
    /// The item expires after a time duration of given hours from now.
    case hours(Int32)
    /// The item expires after a time duration of given days from now.
    case days(Int32)
    /// Indicates the item is already expired. Use this to remove cache
    case expired
    
    var isExpired: Bool {
        return timeInterval <= 0
    }
    
    var timeInterval: Int32 {
        switch self {
        case .never: return .max
        case .seconds(let seconds): return seconds
        case .minutes(let minutes): return Int32(TimeConstants.secondsInOneMinute) * minutes
        case .hours(let hours): return Int32(TimeConstants.secondsInOneHour) * hours
        case .days(let days): return Int32(TimeConstants.secondsInOneDay) * days
        case .expired: return -(.max)
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

/*
 Cache type of a cached image.
 - none: The image is not cached yet when retrieving it.
 - memory: The image is cached in memory.
 - disk: The image is cached in disk.
 - all: The image is cached both in disk and memory.
 */
public struct ImageCacheType: OptionSet {
    public let rawValue: Int
    /// The image is not cached yet when retrieving it.
    public static let none = ImageCacheType([])
    /// The image is cached in memory.
    public static let memory = ImageCacheType(rawValue: 1 << 0)
    /// The image is cached in disk.
    public static let disk = ImageCacheType(rawValue: 1 << 1)
    /// The image is cached both in disk and memory.
    public static let all: ImageCacheType = [.memory, .disk]
    
    public init(rawValue: Int) { self.rawValue = rawValue }
}

/*
 Represents the cache query result type. Used in cache query methods completion.
 
 Capturing associated values in some cases.
 */
public enum ImageCacheQueryCompletionResult {
    /// No result
    case none
    /// Query cache hitted in memory. storing a `UIImage`.
    case memory(image: UIImage)
    /// Query cache hitted in disk. storing a `Data`.
    case disk(data: Data)
    /// Query cache hitted both in memory and disk. storing `UIImage` and `Data`.
    case all(image: UIImage, data: Data)
}

/*
Represents a cache which can store/remove/query UIImage and UIImage Data.
*/
public protocol ImageCacheable: AnyObject {

    /// Query image from `memory` or `disk` and return the `ImageCacheQueryCompletionResult` by the completion handler/
    /// Typically, if memory cache hitted, the completion handler will called synchronous from current thread.
    /// If disk cache hitted, the completion handler will called asynchronous from a background queue.
    func image(forKey key: String, cacheType: ImageCacheType, completion: @escaping (ImageCacheQueryCompletionResult) -> Void)

    /// Check whether disk cache exist datas by the `key`
    func diskDataExists(forKey key: String, completion: ((Bool) -> Void)?)

    /// Store image or data to the memory cache or disk cache 
    func store(_ image: UIImage?,
               data: Data?,
               forKey key: String,
               cacheType: ImageCacheType,
               completion: (() -> Void)?)

    /// Remove image or data to the memory cache or disk cache by the specific key.
    func removeImage(forKey key: String, cacheType: ImageCacheType, completion: ((_ key: String) -> Void)?)

    /// Remove all images or datas to the memory cache or disk cache.
    func remove(_ type: ImageCacheType, completion: (() -> Void)?)
}
