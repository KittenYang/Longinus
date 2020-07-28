//
//  BBImageCache.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/3.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

/// BBImageCacheType specifies how image is cached
public struct BBImageCacheType: OptionSet {
    public let rawValue: Int
    
    /// Image is not cached
    public static let none = BBImageCacheType(rawValue: 0)
    
    /// Image is cached in memory
    public static let memory = BBImageCacheType(rawValue: 1 << 0)
    
    /// Image is cached in disk
    public static let disk = BBImageCacheType(rawValue: 1 << 1)
    
    /// Image is cached in both memory and disk
    public static let all: BBImageCacheType = [.memory, .disk]
    
    public init(rawValue: Int) { self.rawValue = rawValue }
}

/// Result of querying image from cache
public enum BBImageCacheQueryCompletionResult {
    /// No image found
    case none
    
    /// Image found in memory
    case memory(image: UIImage)
    
    /// Image data found in disk
    case disk(data: Data)
    
    /// Image found in memory and image data found in disk
    case all(image: UIImage, data: Data)
}

public typealias BBImageCacheQueryCompletion = (BBImageCacheQueryCompletionResult) -> Void
public typealias BBImageCacheCheckDiskCompletion = (Bool) -> Void
public typealias BBImageCacheStoreCompletion = () -> Void
public typealias BBImageCacheRemoveCompletion = () -> Void

/// BBImageCache defines image querying, storing and removing behaviors
public protocol BBImageCache: AnyObject {
    /// Gets image with key and cache type
    ///
    /// - Parameters:
    ///   - key: cache key
    ///   - cacheType: cache type specifying how image is cached
    ///   - completion: a closure called when querying is finished
    func image(forKey key: String, cacheType: BBImageCacheType, completion: @escaping BBImageCacheQueryCompletion)
    
    /// Checks whether image data is in the disk cache
    ///
    /// - Parameters:
    ///   - key: cache key
    ///   - completion: a closure called when checking is finished
    func diskDataExists(forKey key: String, completion: @escaping BBImageCacheCheckDiskCompletion)
    
    /// Stores image and/or data with key and cache type
    ///
    /// - Parameters:
    ///   - image: image to store
    ///   - data: data to store
    ///   - key: cache key
    ///   - cacheType: cache type specifying how image is cached
    ///   - completion: a closure called when storing is finished
    func store(_ image: UIImage?,
               data: Data?,
               forKey key: String,
               cacheType: BBImageCacheType,
               completion: BBImageCacheStoreCompletion?)
    
    /// Removes value with key and cache type
    ///
    /// - Parameters:
    ///   - key: cache key
    ///   - cacheType: cache type specifying how image is cached
    ///   - completion: a closure called when removing is finished
    func removeImage(forKey key: String, cacheType: BBImageCacheType, completion: BBImageCacheRemoveCompletion?)
    
    /// Removes all values with cache type
    ///
    /// - Parameters:
    ///   - type: cache type specifying how image is cached
    ///   - completion: a closure called when clearing is finished
    func clear(_ type: BBImageCacheType, completion: BBImageCacheRemoveCompletion?)
}

/// BBLRUImageCache is a key-value image cache using least recently used algorithm
public class BBLRUImageCache: BBImageCache {
    public let memoryCache: BBMemoryCache
    public let diskCache: BBDiskCache?
    public weak var imageCoder: BBImageCoder?
    
    /// Creates a BBLRUImageCache object
    ///
    /// - Parameters:
    ///   - path: directory storing image data
    ///   - sizeThreshold: threshold specifying image data is store in sqlite (data.count <= threshold) or file (data.count > threshold)
    init(path: String, sizeThreshold: Int) {
        memoryCache = BBMemoryCache()
        diskCache = BBDiskCache(path: path, sizeThreshold: sizeThreshold)
    }
    
    public func image(forKey key: String, cacheType: BBImageCacheType, completion: @escaping BBImageCacheQueryCompletion) {
        var memoryImage: UIImage?
        if cacheType.contains(.memory),
            let image = memoryCache.image(forKey: key) {
            if cacheType == .all {
                memoryImage = image
            } else {
                return completion(.memory(image: image))
            }
        }
        if cacheType.contains(.disk),
            let currentDiskCache = diskCache {
            return currentDiskCache.data(forKey: key) { (data) in
                if let currentData = data {
                    if cacheType == .all,
                        let currentImage = memoryImage {
                        completion(.all(image: currentImage, data: currentData))
                    } else {
                        completion(.disk(data: currentData))
                    }
                } else if let currentImage = memoryImage {
                    // Cache type is all
                    completion(.memory(image: currentImage))
                } else {
                    completion(.none)
                }
            }
        }
        completion(.none)
    }
    
    public func diskDataExists(forKey key: String, completion: @escaping BBImageCacheCheckDiskCompletion) {
        guard let currentDiskCache = diskCache else { return completion(false) }
        currentDiskCache.dataExists(forKey: key, completion: completion)
    }
    
    public func store(_ image: UIImage?,
                      data: Data?,
                      forKey key: String,
                      cacheType: BBImageCacheType,
                      completion: BBImageCacheStoreCompletion?) {
        if cacheType.contains(.memory),
            let currentImage = image {
            memoryCache.store(currentImage, forKey: key, cost: currentImage.cgImage?.bb_bytes ?? 1)
        }
        if cacheType.contains(.disk),
            let currentDiskCache = diskCache {
            if let currentData = data {
                return currentDiskCache.store(currentData, forKey: key, completion: completion)
            }
            return currentDiskCache.store({ [weak self] () -> Data? in
                guard let self = self else { return nil }
                if let currentImage = image,
                    let coder = self.imageCoder,
                    let data = coder.encodedData(with: currentImage, format: currentImage.bb_imageFormat ?? .unknown) {
                    return data
                }
                return nil
            }, forKey: key, completion: completion)
        }
        completion?()
    }
    
    public func removeImage(forKey key: String, cacheType: BBImageCacheType, completion: BBImageCacheRemoveCompletion?) {
        if cacheType.contains(.memory) { memoryCache.removeImage(forKey: key) }
        if cacheType.contains(.disk),
            let currentDiskCache = diskCache {
            return currentDiskCache.removeData(forKey: key, completion: completion)
        }
        completion?()
    }
    
    public func clear(_ type: BBImageCacheType, completion: BBImageCacheRemoveCompletion?) {
        if type.contains(.memory) { memoryCache.clear() }
        if type.contains(.disk),
            let currentDiskCache = diskCache {
            return currentDiskCache.clear(completion)
        }
        completion?()
    }
}
