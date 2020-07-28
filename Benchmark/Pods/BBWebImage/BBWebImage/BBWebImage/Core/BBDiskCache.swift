//
//  BBDiskCache.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/29.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

/// BBDiskCache is a key-value disk cache using least recently used algorithm
public class BBDiskCache {
    private let storage: BBDiskStorage
    private let sizeThreshold: Int
    private let queue: BBDispatchQueuePool
    private var costLimit: Int
    private var countLimit: Int
    private var ageLimit: TimeInterval
    
    /// Crreates a BBDiskCache object
    ///
    /// - Parameters:
    ///   - path: directory storing image data
    ///   - threshold: threshold specifying image data is store in sqlite (data.count <= threshold) or file (data.count > threshold)
    public init?(path: String, sizeThreshold threshold: Int) {
        if let currentStorage = BBDiskStorage(path: path) {
            storage = currentStorage
        } else {
            return nil
        }
        sizeThreshold = threshold
        queue = BBDispatchQueuePool.utility
        costLimit = .max
        countLimit = .max
        ageLimit = .greatestFiniteMagnitude
        trimRecursively()
    }
    
    /// Gets data with key synchronously
    ///
    /// - Parameter key: cache key
    /// - Returns: data in disk, or nil if no data found
    public func data(forKey key: String) -> Data? {
        return storage.data(forKey: key)
    }
    
    /// Gets data with key asynchronously
    ///
    /// - Parameters:
    ///   - key: cache key
    ///   - completion: a closure called when querying is finished
    public func data(forKey key: String, completion: @escaping (Data?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            completion(self.data(forKey: key))
        }
    }
    
    /// Checks whether data is in the disk cache.
    /// This method checks cache synchronously.
    ///
    /// - Parameters:
    ///   - key: cache key
    /// - Returns: true if data is in the cache, or false if not
    public func dataExists(forKey key: String) -> Bool {
        return storage.dataExists(forKey: key)
    }
    
    /// Checks whether data is in the disk cache.
    /// This method checks cache asynchronously.
    ///
    /// - Parameters:
    ///   - key: cache key
    ///   - completion: a closure called when checking is finished
    public func dataExists(forKey key: String, completion: @escaping BBImageCacheCheckDiskCompletion) {
        queue.async { [weak self] in
            guard let self = self else { return }
            completion(self.dataExists(forKey: key))
        }
    }
    
    /// Stores data with key synchronously
    ///
    /// - Parameters:
    ///   - data: data to store
    ///   - key: cache key
    public func store(_ data: Data, forKey key: String) {
        storage.store(data, forKey: key, type: (data.count > sizeThreshold ? .file : .sqlite))
    }
    
    /// Stores data with key asynchronously
    ///
    /// - Parameters:
    ///   - data: data to store
    ///   - key: cache key
    ///   - completion: a closure called when storing is finished
    public func store(_ data: Data, forKey key: String, completion: BBImageCacheStoreCompletion?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.store(data, forKey: key)
            completion?()
        }
    }
    
    /// Stores data with data work closure and key asynchronously
    ///
    /// - Parameters:
    ///   - dataWork: a closure called in a background thread, returning data
    ///   - key: cache key
    ///   - completion: a closure called when storing is finished
    public func store(_ dataWork: @escaping () -> Data?, forKey key: String, completion: BBImageCacheStoreCompletion?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = dataWork() {
                self.store(data, forKey: key)
            }
            completion?()
        }
    }
    
    /// Removes data with key synchronously
    ///
    /// - Parameter key: cache key
    public func removeData(forKey key: String) {
        storage.removeData(forKey: key)
    }
    
    /// Removes data with key asynchronously
    ///
    /// - Parameters:
    ///   - key: cache key
    ///   - completion: a closure called when removing is finished
    public func removeData(forKey key: String, completion: BBImageCacheRemoveCompletion?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.removeData(forKey: key)
            completion?()
        }
    }
    
    /// Removes all data synchronously
    public func clear() {
        storage.clear()
    }
    
    /// Removes all data asynchronously
    ///
    /// - Parameter completion: a closure called when clearing is finished
    public func clear(_ completion: BBImageCacheRemoveCompletion?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.clear()
            completion?()
        }
    }
    
    private func trimRecursively() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self = self else { return }
            self.storage.trim(toCost: self.costLimit)
            self.storage.trim(toCount: self.countLimit)
            self.storage.trim(toAge: self.ageLimit)
            self.trimRecursively()
        }
    }
}
