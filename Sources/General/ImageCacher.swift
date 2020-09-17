//
//  ImageCacher.swift
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
    

import UIKit

/**
ImageCacher is a cache that stores UIImage and image data based on memory cache and disk cache.

@discussion The disk cache will try to protect the original image data:

* If the original image is still image, it will be saved as png/jpeg file based on alpha information.
* If the original image is animated gif, it will be saved as original format.

Although UIImage can be serialized with NSCoding protocol, but it's not a good idea:
Apple actually use UIImagePNGRepresentation() to encode all kind of image, it may
lose the original multi-frame data. The result is packed to plist file and cannot
view with photo viewer directly. If the image has no alpha channel, using JPEG
instead of PNG can save more disk size and encoding/decoding time.
*/
public class ImageCacher {

    /** The underlying memory cache. see `MemoryCache` for more information.*/
    public let memoryCache: MemoryCache<String, UIImage>
    
    /** The underlying disk cache. see `DiskCache` for more information.*/
    public let diskCache: DiskCache?
    
    /** The weak refrense to imageCoder to encode image if `Data` is not provided in `store(image: ,data:)` method.*/
    public weak var imageCoder: ImageCodeable?
    
    /**
     The designated initializer. Multiple instances with the same path will make the
     cache unstable.
     
     - Parameters:
        - path: Full path of a directory in which the cache will write data.
        Once initialized you should not read and write to this directory.
        - sizeThreshold: Determine the object should store to sqlite or file system.
    */
    init?(path: String, sizeThreshold: Int32) {
        memoryCache = MemoryCache()
        diskCache = DiskCache(path: path, sizeThreshold: sizeThreshold)
        if diskCache == nil { return nil }
    }
    
    /*
     Empties the cache.
     This method may blocks the calling thread until file delete finished.
     */
    public func removeAll() {
        memoryCache.removeAll()
        diskCache?.removeAll()
    }
    
    /**
     Empties the cache.
     This method returns immediately and invoke the passed block in background queue
     when the operation finished.
     
     - Parameters:
        - completion: A block which will be invoked in background queue when finished.
     */
    public func removeAll(_ completion: @escaping ()->Void) {
        memoryCache.removeAll()
        diskCache?.removeAll({
            completion()
        })
    }
    
}

extension ImageCacher: ImageCacheable {

    public func image(forKey key: String, cacheType: ImageCacheType, completion: @escaping (ImageCacheQueryCompletionResult) -> Void) {
        var memoryImage: UIImage?
        if cacheType.contains(.memory),
            let image = memoryCache.query(key: key) {
            if cacheType == .all {
                memoryImage = image
            } else {
                return completion(.memory(image: image))
            }
        }
        if cacheType.contains(.disk),
            let currentDiskCache = diskCache {
            return currentDiskCache.query(key: key) { (imageKey, imageData) in
                if let currentData = imageData {
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
    
    public func isCached(forKey key: String) -> (Bool, ImageCacheType) {
        let memoryContain = memoryCache.containsObject(key: key)
        guard let currentDiskCache = diskCache else {
            if memoryContain {
                return (true, .memory)
            }
            return (false, .none)
        }
        let diskContain = currentDiskCache.containsObject(key: key)
        if diskContain {
            if memoryContain {
                return (true, .all)
            } else {
                return (true, .disk)
            }
        } else {
            if memoryContain {
                return (true, .memory)
            } else {
                return (false, .none)
            }
        }
        
    }
    
    public func diskDataExists(forKey key: String, completion: ((Bool) -> Void)?) {
        guard let currentDiskCache = diskCache else {
            completion?(false)
            return
        }
        currentDiskCache.containsObject(key: key) { (_, contain) in
            completion?(contain)
        }
    }
    
    /*
     Store image or data to the memory cache or disk cache
     If need to store to memory, it will save the UIImage objects to the LRU linkedMap.
     If need to store to disk, it will save the data to the disk. If input data is nil, it will use a `dataWork` operation to encoded image to Data according to the image type.
     Note: It will only save the save the ORIGINAL image data to the disk.
     Note: If memory cache stored successfully, the completion handler will called in current thread synchronous.
     Note: If disk cache stored successfully, the completion handler will called in background thread a synchronous.
     */
    public func store(_ image: UIImage?, data: Data?, forKey key: String, cacheType: ImageCacheType, completion: (() -> Void)?) {
        if cacheType.contains(.memory),
            let currentImage = image {
            memoryCache.save(value: currentImage, for: key, cost: Int(currentImage.cacheCost))
        }
        if cacheType.contains(.disk),
            let currentDiskCache = diskCache {
            // Save the original image data to disk
            if let currentData = data {
                if let completion = completion {
                    return currentDiskCache.save(value: currentData, for: key, completion)
                } else {
                    return currentDiskCache.save(value: currentData, for: key)
                }
            }
            let dataWork = { [weak self] () -> (Data, Int)? in
                guard let self = self else { return nil }
                if let currentImage = image,
                    let coder = self.imageCoder,
                    let data = coder.encodedData(with: currentImage, format: currentImage.lg.imageFormat ?? .unknown) {
                    return (data, data.count)
                }
                return nil
            }
            if let completion = completion {
                return currentDiskCache.save(dataWork, forKey: key, result: completion)
            } else {
                return currentDiskCache.save(dataWork, forKey: key)
            }
        }
        completion?()
    }
    
    /*
     Remove image from the memory cache or remove data from the disk cache by the specific key.
     Note: If memory cache removed successfully, the completion handler will called in current thread synchronous.
     Note: If disk cache removed successfully, the completion handler will called in background thread a synchronous.
     */
    public func removeImage(forKey key: String, cacheType: ImageCacheType, completion: ((String) -> Void)?) {
        if cacheType.contains(.memory) { memoryCache.remove(key: key) }
        if cacheType.contains(.disk),
            let currentDiskCache = diskCache {
            if let completion = completion {
                return currentDiskCache.remove(key: key, completion)
            } else {
                return currentDiskCache.remove(key: key)
            }
        }
        completion?(key)
    }
    
    /*
     Remove all images or datas to the memory cache or disk cache.
     Note: If memory cache removed successfully, the completion handler will called in current thread synchronous.
     Note: If disk cache removed successfully, the completion handler will called in background thread a synchronous.
     */
    public func remove(_ type: ImageCacheType, completion: (() -> Void)?) {
        if type.contains(.memory) { memoryCache.removeAll() }
        if type.contains(.disk),
            let currentDiskCache = diskCache {
            if let completion = completion {
                return currentDiskCache.removeAll(completion)
            } else {
                return currentDiskCache.removeAll()
            }
        }
        completion?()
    }
    
}
