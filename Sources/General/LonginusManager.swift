//
//  LonginusManager.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/13.
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

/// Represents the result of a Longinus query image task.
public struct QueryImageCacheResult {

    /// Gets the image object of this result.
    public private(set) var image: UIImage?
    
    /// Gets the image format of this result.
    public private(set) var imageFormat: ImageFormat? = .unknown
    
    /// If image cached on disk. return the cached data by the way if needed.
    public private(set) var data: Data?
    
    /// Whether query error happened.
    public private(set) var error: Error?

    /// Gets the cache type of the image.
    public private(set) var cacheType: ImageCacheType = .none
    
    init(image: UIImage? = nil, data: Data? = nil, error: Error? = nil, cacheType: ImageCacheType = .none) {
        self.image = image
        self.imageFormat = image?.lg.imageFormat
        self.data = data
        self.error = error
        self.cacheType = cacheType
    }

}

/**
A manager to create and manage web image operation.
*/
public class LonginusManager {
    
    /**
     Returns global LonginusManager instance.
     
     The Default `sizeThreshold` value is 20KB
     */
    public static let shared: LonginusManager = { () -> LonginusManager in
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! + "/\(LonginusPrefixID)"
        return LonginusManager(cachePath: path, sizeThreshold: 20 * 1_024)
    }()
    
    /**
    The image cache used by image operation.
    You can set it to nil to avoid image cache.
    */
    public private(set) var imageCacher: ImageCacher?
    
    /**
     The object which conforms `ImageDownloadable` protocol.
     The default object is `ImageDownloader`
     */
    public private(set) var imageDownloader: ImageDownloadable
    
    /**
     The object which conforms `ImageCodeable` protocol.
     The default object is `ImageCoderManager`
     */
    public private(set) var imageCoder: ImageCodeable
    
    /**
     The dictionary holds preloading tasks.
     */
    public private(set) var preloadTasks: [String: ImageLoadTask]
    
    /**
     Default options used by the manager. This option will be used in
     LonginusManager related methods, as well as all view extension methods.
     You can also passing other options for each image task by sending an `options` parameter
     to Longinus's APIs. The per image options will overwrite the default ones,
     if the option exists in both.
     */
    public var defaultOptions = LonginusImageOptions.empty
    
    /**
     Return the current tasks count
     */
    public var currentTaskCount: Int {
        taskLock.lock()
        let count = self.tasks.count
        taskLock.unlock()
        return count
    }
    
    /**
     Return the current preload tasks count
     */
    public var currentPreloadTaskCount: Int {
        taskLock.lock()
        let count = self.preloadTasks.count
        taskLock.unlock()
        return count
    }
    
    /**
     The queue for image coding and caching.
     This queue handled by `DispatchQueuePool`. Check this class for more details.
     */
    private let coderQueue: DispatchQueuePool = DispatchQueuePool.userInitiated
    
    /**
     The queue for releasing `ImageLoadTask`
     This queue handled by `DispatchQueuePool`. Check this class for more details.
     */
    private let releaseQueue: DispatchQueuePool = DispatchQueuePool.background

    /**
     The dictionary holds loading tasks.
     */
    private var tasks: Set<ImageLoadTask>

    /**
     The lock to protect `tasks` or `preloadTasks` safety
     */
    private var taskLock: Mutex
    
    /**
     The lock to protect `urlBlacklist` safety
     */
    private var urlBlacklistLock: Mutex
    
    /**
     The global sentinel to mark every task unique
     */
    private var taskSentinel: Int32
    
    /**
     The blacklist url sets to ignore download urls
     */
    private var urlBlacklist: Set<URL>
    
    
    /**
     The convenience initialize method to generate a manager
     - Parameters:
        - cachePath: The path to save files or sqlite
        - sizeThreshold: Determine the object should store to sqlite or file system.
     */
    public convenience init(cachePath: String, sizeThreshold: Int32) {
        let cache = ImageCacher(path: cachePath, sizeThreshold: sizeThreshold)
        let downloader = ImageDownloader(sessionConfiguration: URLSessionConfiguration.default)
        let coder = ImageCoderManager()
        cache?.imageCoder = coder
        downloader.imageCoder = coder

        self.init(cacher: cache, downloader: downloader, coder: coder)
    }
    
    /**
     The designed initialize method
     
     - Parameters:
        - cacher: a `ImageCacher` object to handle cache operations
        - downloader: a `ImageDownloadable` object to handle download operations. This class use `ImageDownloader`. You can customize this object which conforms `ImageDownloadable` protocal
        - coder: a `ImageCodeable` object to handle encode/decode operations. This class use `ImageCoderManager`. You can customize this object which conforms `ImageCodeable` protocal
     */
    public init(cacher: ImageCacher?, downloader: ImageDownloadable, coder: ImageCodeable) {
        imageCacher = cacher
        imageDownloader = downloader
        imageCoder = coder
        tasks = Set()
        preloadTasks = [:]
        taskSentinel = 0
        taskLock = Mutex()
        urlBlacklistLock = Mutex()
        urlBlacklist = Set()
    }
    
    /**
     Creates and returns a new `ImageLoadTask`, the operation will start immediately.
     - Parameters:
        - resource:    The object conforms `ImageWebCacheResourceable` protocol. Typically will be a `URL`.
        - options:     The options to control image operation.
        - transformer: Transform block which will be invoked on background thread  (pass nil to avoid).
        - progress:    Progress block which will be invoked on background thread (pass nil to avoid).
        - completion:  Completion block which will be invoked on background thread  (pass nil to avoid).
     */
    @discardableResult
    public func loadImage(with resource: ImageWebCacheResourceable,
                          options: LonginusImageOptions? = nil,
                          transformer: ImageTransformer? = nil,
                          progress: ImageDownloaderProgressBlock? = nil,
                          completion: @escaping ImageManagerCompletionBlock) -> ImageLoadTask {
        let task = newLoadTask(url: resource.downloadUrl)
        let options = defaultOptions + (options ?? .empty)
        let optionsInfo = LonginusParsedImageOptionsInfo(options)
        taskLock.lock()
        self.tasks.insert(task)
        if optionsInfo.preload { self.preloadTasks[resource.cacheKey] = task }
        taskLock.unlock()
        
        if !optionsInfo.retryFailedUrl {
            var inBlacklist: Bool = false
            urlBlacklistLock.lock()
            inBlacklist = self.urlBlacklist.contains(resource.downloadUrl)
            urlBlacklistLock.unlock()

            if inBlacklist {
                complete(with: task, completion: completion, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: [NSLocalizedDescriptionKey : "URL is blacklisted"]))
                remove(loadTask: task)
                return task
            }
        }
        
        if optionsInfo.refreshCache {
            downloadImage(with: resource,
                          options: options,
                          task: task,
                          transformer: transformer,
                          progress: progress,
                          completion: completion)
            return task
        }
        
        // Get memory image
        var memoryImage: UIImage?
        imageCacher?.image(forKey: resource.cacheKey, cacheType: .memory) { (result: ImageCacheQueryCompletionResult) in
            switch result {
            case let .memory(image: image):
                memoryImage = image
            default:
                break
            }
        }
        var finished = false
        if let currentImage = memoryImage {
            if optionsInfo.preload {
                complete(with: task,
                         completion: completion,
                         image: currentImage,
                         data: nil,
                         cacheType: .memory)
                remove(loadTask: task)
                finished = true
            } else if !optionsInfo.queryDataWhenInMemory {
                if var animatedImage = currentImage as? AnimatedImage {
                    animatedImage.lg.transformer = transformer
                    complete(with: task,
                             completion: completion,
                             image: animatedImage,
                             data: nil,
                             cacheType: .memory)
                    remove(loadTask: task)
                    finished = true
                } else if let currentTransformer = transformer {
                    if currentTransformer.key == currentImage.lg.lgImageEditKey {
                        complete(with: task,
                                 completion: completion,
                                 image: currentImage,
                                 data: nil,
                                 cacheType: .memory)
                        remove(loadTask: task)
                        finished = true
                    } else if currentImage.lg.lgImageEditKey == nil {
                        coderQueue.async { [weak self, weak task] in
                            guard let self = self, let task = task, !task.isCancelled else { return }
                            if var image = currentTransformer.transform(currentImage) {
                                guard !task.isCancelled else { return }
                                image.lg.lgImageEditKey = currentTransformer.key
                                image.lg.imageFormat = currentImage.lg.imageFormat
                                self.complete(with: task,
                                              completion: completion,
                                              image: image,
                                              data: nil,
                                              cacheType: .memory)
                                self.imageCacher?.store(image,
                                                        data: nil,
                                                        forKey: resource.cacheKey,
                                                        cacheType: .memory,
                                                        completion: nil)
                            } else {
                                self.complete(with: task, completion: completion, error: NSError(domain: LonginusImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "No edited image"]))
                            }
                            self.remove(loadTask: task)
                        }
                        finished = true
                    }
                } else if currentImage.lg.lgImageEditKey == nil {
                    complete(with: task,
                             completion: completion,
                             image: currentImage,
                             data: nil,
                             cacheType: .memory)
                    remove(loadTask: task)
                    finished = true
                }
            }
        }
        if finished { return task }
        
        if optionsInfo.ignoreDiskCache || resource.downloadUrl.isFileURL {
            var mutableOptions = options
            mutableOptions.append(.ignoreDiskCache)
            downloadImage(with: resource,
                          options: mutableOptions,
                          task: task,
                          transformer: transformer,
                          progress: progress,
                          completion: completion)
        } else if optionsInfo.preload {
            // Check whether disk data exists
            self.imageCacher?.diskDataExists(forKey: resource.cacheKey) { [weak self] (exists) in
                if exists {
                    self?.complete(with: task,
                                   completion: completion,
                                   image: nil,
                                   data: nil,
                                   cacheType: .disk)
                    self?.remove(loadTask: task)
                } else {
                    self?.downloadImage(with: resource,
                                        options: options,
                                        task: task,
                                        transformer: transformer,
                                        progress: progress,
                                        completion: completion)
                }
            }
        } else {
            // Get disk data
            self.imageCacher?.image(forKey: resource.cacheKey, cacheType: .disk) { [weak self, weak task] (result: ImageCacheQueryCompletionResult) in
                guard let self = self, let task = task, !task.isCancelled else { return }
                switch result {
                case let .disk(data: data):
                    self.handle(imageData: data,
                                optionsInfo: optionsInfo,
                                cacheType: (memoryImage != nil ? .all : .disk),
                                forTask: task,
                                resource: resource,
                                transformer: transformer,
                                completion: completion)
                case .none:
                    // Download
                    self.downloadImage(with: resource,
                                       options: options,
                                       task: task,
                                       transformer: transformer,
                                       progress: progress,
                                       completion: completion)
                default:
                    LGPrint("Error: illegal query disk data result")
                    break
                }
            }
        }
        return task
    }
    
    /**
     Creates and returns a new preload `ImageLoadTask`, the operation will start immediately.
     This method will not decoding or decompress image or memory caching for showing. Only will download images then cache to the disk for getting later.
     
     Typically, you can use this method for downloading those images that will show but not show yet in advance during idle time. Or use this method in UITableView/UICollectionView `DataSourcePrefetching` methods.
     
     If a preload task not finished but a normal task coming, dont worry, it will automaticlly upgrade the preload task to the normal task.
     
     - Parameters:
        - resource:    The object conforms `ImageWebCacheResourceable` protocol. Typically will be a `URL`.
        - options:     The options to control image operation.
        - transformer: Transform block which will be invoked on background thread  (pass nil to avoid).
        - progress:    Progress block which will be invoked on background thread (pass nil to avoid).
        - completion:  Completion block which will be invoked on background thread  (pass nil to avoid).
     */
    @discardableResult
    public func preload(_ resources: [ImageWebCacheResourceable],
                        options: LonginusImageOptions? = nil,
                        progress: ImagePreloadProgress? = nil,
                        completion: ImagePreloadCompletion? = nil) -> [ImageLoadTask] {
        cancelPreloading()
        let total = resources.count
        if total <= 0 { return [] }
        var finishCount = 0
        var successCount = 0
        var tasks: [ImageLoadTask] = []
        for resource in resources {
            let options = defaultOptions + (options ?? .empty)
            let optionInfo = LonginusParsedImageOptionsInfo(options)
            var currentOptions: LonginusImageOptions = [.preload]
            if optionInfo.useURLCache { currentOptions += [.useURLCache] }
            if optionInfo.handleCookies { currentOptions += [.handleCookies] }
            if let httpHeadersModifier = optionInfo.httpHeadersModifier {
                currentOptions += [.httpHeadersModifier(httpHeadersModifier)]
            }
            if let requestModifier = optionInfo.requestModifier {
                currentOptions += [.requestModifier(requestModifier)]
            }
            let task = loadImage(with: resource, options: currentOptions) { (_, _, error, _) in
                finishCount += 1
                if error == nil { successCount += 1 }
                progress?(successCount, finishCount, total)
                if finishCount >= total {
                    completion?(successCount, total)
                }
            }
            tasks.append(task)
        }
        return tasks
    }
    
    /**
     Cancel preloading task by the url
     - Parameters:
        - url: The url request need to cancel
     */
    public func cancelPreloading(url: String) {
        taskLock.lock()
        let currentTask = preloadTasks[url]
        taskLock.unlock()
        currentTask?.cancel()
    }

    /**
     Cancels all image preloading tasks
     */
    public func cancelPreloading() {
        taskLock.lock()
        let currentTasks = preloadTasks
        taskLock.unlock()
        for task in currentTasks.values {
            task.cancel()
        }
    }
    
    /**
     Cancels all image tasks
     */
    public func cancelAll() {
        taskLock.lock()
        let currentTasks = tasks
        taskLock.unlock()
        for task in currentTasks {
            task.cancel()
        }
    }
    
    /**
     Returns the `QueryImageCacheResult` associated with a given key.
     If the image is not in memory, this method may blocks the calling thread until
     file read finished.
     
     @param key A string identifying the image. If nil, just return nil.
     @return The `QueryImageCacheResult` associated with key.
     */
    public func queryImageFromCacheWithType(byKey key: String, cacheType: ImageCacheType = .all) -> QueryImageCacheResult {
        if cacheType.contains(.memory) {
            if let image = imageCacher?.memoryCache.query(key: key) {
                return QueryImageCacheResult(image: image, cacheType: .memory)
            }
        }
        if cacheType.contains(.disk) {
            if let data = imageCacher?.diskCache?.query(key: key) {
                var finalImage: UIImage? = self.imageCoder.decodedImage(with: data)
                if let animatedImage = finalImage as? AnimatedImage {
                    if cacheType.contains(.memory) {
                        imageCacher?.store(animatedImage, data: nil, forKey: key, cacheType: .memory, completion: nil)
                    }
                    return QueryImageCacheResult(image: animatedImage, cacheType: .disk)
                } else {
                    if let _decodedImage = finalImage {
                        finalImage = self.imageCoder.decompressedImage(with: _decodedImage, data: data)
                        if cacheType.contains(.memory) {
                            imageCacher?.store(finalImage, data: nil, forKey: key, cacheType: .memory, completion: nil)
                        }
                        return QueryImageCacheResult(image: finalImage, cacheType: .disk)
                    }
                }
            }
        }
        return QueryImageCacheResult(error: NSError(domain: LonginusImageErrorDomain, code: 1001, userInfo: [NSLocalizedDescriptionKey : "No cached image finded either in disk or memory"]))
    }
    
    /**
     Asynchronously get the `QueryImageCacheResult` associated with a given key.
     
     @param key   A string identifying the image. If nil, just return nil.
     @param type  The cache type.
     @param completion A completion block which will be called on main thread.
     */
    public func queryImageFromCacheWithType(byKey key: String, cacheType: ImageCacheType, completion: @escaping (QueryImageCacheResult)->Void) {
        DispatchQueue.global().async {
            let result = self.queryImageFromCacheWithType(byKey: key, cacheType: cacheType)
            DispatchQueue.main.lg.safeAsync {
                completion(result)
            }
        }
    }
    
    /**
     Remove the image load task from normal tasks sets and preloadTasks dic
     */
    func remove(loadTask: ImageLoadTask) {
        releaseQueue.async { [weak self] in
            self?.taskLock.lock()
            self?.tasks.remove(loadTask)
            self?.preloadTasks.removeValue(forKey: loadTask.url.absoluteString)
            self?.taskLock.unlock()
        }
    }

}

// MARK: Helper
extension LonginusManager {
    private func newLoadTask(url: URL) -> ImageLoadTask {
        let task = ImageLoadTask(sentinel: OSAtomicIncrement32(&taskSentinel), url: url)
        task.imageManager = self
        return task
    }
    
    private func handle(imageData data: Data,
                        optionsInfo: LonginusParsedImageOptionsInfo,
                        cacheType: ImageCacheType,
                        forTask task: ImageLoadTask,
                        resource: ImageWebCacheResourceable,
                        transformer: ImageTransformer?,
                        completion: @escaping ImageManagerCompletionBlock) {
        if optionsInfo.preload {
            complete(with: task,
                     completion: completion,
                     image: nil,
                     data: data,
                     cacheType: cacheType)
            if cacheType == .none {
                imageCacher?.store(nil, data: data, forKey: resource.cacheKey, cacheType: .disk, completion: nil)
            }
            remove(loadTask: task)
            return
        }
        self.coderQueue.async { [weak self, weak task] in
            guard let self = self, let task = task, !task.isCancelled else { return }
            var decodedImage = self.imageCoder.decodedImage(with: data)
            if let currentTransformer = transformer {
                if let animatedImage = decodedImage as? AnimatedImage {
                    if optionsInfo.ignoreAnimatedImage {
                        decodedImage = animatedImage.imageFrame(at: 0, decompress: !optionsInfo.ignoreImageDecoding)
                    }
                }
                if var animatedImage = decodedImage as? AnimatedImage {
                    animatedImage.lg.transformer = currentTransformer
                    self.complete(with: task,
                                  completion: completion,
                                  image: animatedImage,
                                  data: data,
                                  cacheType: cacheType)
                    let storeCacheType: ImageCacheType = (cacheType == .disk || optionsInfo.ignoreDiskCache ? .memory : .all)
                    self.imageCacher?.store(animatedImage,
                                            data: data,
                                            forKey: resource.cacheKey,
                                            cacheType: storeCacheType,
                                            completion:nil)
                } else if let inputImage = decodedImage {
                    if var image = currentTransformer.transform(inputImage) {
                        guard !task.isCancelled else { return }
                        image.lg.lgImageEditKey = currentTransformer.key
                        image.lg.imageFormat = data.lg.imageFormat
                        self.complete(with: task,
                                      completion: completion,
                                      image: image,
                                      data: data,
                                      cacheType: cacheType)
                        let storeCacheType: ImageCacheType = (cacheType == .disk || optionsInfo.ignoreDiskCache ? .memory : .all)
                        self.imageCacher?.store(image,
                                                data: data,
                                                forKey: resource.cacheKey,
                                                cacheType: storeCacheType,
                                                completion:nil)
                    } else {
                        self.complete(with: task, completion: completion, error: NSError(domain: LonginusImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "No edited image"]))
                    }
                } else {
                    if cacheType == .none {
                        self.urlBlacklistLock.lock()
                        self.urlBlacklist.insert(resource.downloadUrl)
                        self.urlBlacklistLock.unlock()
                    }
                    self.complete(with: task, completion: completion, error: NSError(domain: LonginusImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Invalid image data"]))
                }
            } else if var image = decodedImage {
                if !optionsInfo.ignoreImageDecoding,
                    let decompressedImage = self.imageCoder.decompressedImage(with: image, data: data) {
                    image = decompressedImage
                }
                if let animatedImage = image as? AnimatedImage, optionsInfo.ignoreAnimatedImage {
                    if let firstFrame = animatedImage.imageFrame(at: 0, decompress: !optionsInfo.ignoreImageDecoding) {
                        image = firstFrame
                    }
                }
                self.complete(with: task,
                              completion: completion,
                              image: image,
                              data: data,
                              cacheType: cacheType)
                let storeCacheType: ImageCacheType = (cacheType == .disk || optionsInfo.ignoreDiskCache ? .memory : .all)
                self.imageCacher?.store(image,
                                        data: data,
                                        forKey: resource.cacheKey,
                                        cacheType: storeCacheType,
                                        completion: nil)
            } else {
                if cacheType == .none {
                    self.urlBlacklistLock.lock()
                    self.urlBlacklist.insert(resource.downloadUrl)
                    self.urlBlacklistLock.unlock()
                }
                self.complete(with: task, completion: completion, error: NSError(domain: LonginusImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Invalid image data"]))
            }
            self.remove(loadTask: task)
        }
    }
    
    private func downloadImage(with resource: ImageWebCacheResourceable,
                               options: LonginusImageOptions?,
                               task: ImageLoadTask,
                               transformer: ImageTransformer?,
                               progress: ImageDownloaderProgressBlock?,
                               completion: @escaping ImageManagerCompletionBlock) {
        task.download = self.imageDownloader.downloadImage(with: resource.downloadUrl, options: options, progress: progress) { [weak self, weak task] (data: Data?, error: Error?) in
            guard let self = self, let task = task, !task.isCancelled else { return }
            let optionsInfo = LonginusParsedImageOptionsInfo(options)
            if let currentData = data {
                if optionsInfo.retryFailedUrl {
                    self.urlBlacklistLock.lock()
                    self.urlBlacklist.remove(resource.downloadUrl)
                    self.urlBlacklistLock.unlock()
                }
                self.handle(imageData: currentData,
                            optionsInfo: optionsInfo,
                            cacheType: .none,
                            forTask: task,
                            resource: resource,
                            transformer: transformer,
                            completion: completion)
            } else if let currentError = error {
                let code = (currentError as NSError).code
                if  code != NSURLErrorNotConnectedToInternet &&
                    code != NSURLErrorCancelled &&
                    code != NSURLErrorTimedOut &&
                    code != NSURLErrorInternationalRoamingOff &&
                    code != NSURLErrorDataNotAllowed &&
                    code != NSURLErrorCannotFindHost &&
                    code != NSURLErrorCannotConnectToHost &&
                    code != NSURLErrorNetworkConnectionLost {
                    self.urlBlacklistLock.lock()
                    self.urlBlacklist.insert(resource.downloadUrl)
                    self.urlBlacklistLock.unlock()
                }
                
                /// If options contain `.refreshCache` but request faild. For example, if http headers set `If-Modified-Since` key-value pairs but server return `304 Not Modified`, it should show last cached image if exist.
                if optionsInfo.refreshCache {
                    // Get last cached image if exist.
                    self.imageCacher?.image(forKey: resource.cacheKey, cacheType: .disk) { [weak self, weak task] (result: ImageCacheQueryCompletionResult) in
                        guard let self = self, let task = task, !task.isCancelled else { return }
                        switch result {
                        case let .disk(data: data):
                            self.handle(imageData: data,
                                        optionsInfo: optionsInfo,
                                        cacheType: .disk,
                                        forTask: task,
                                        resource: resource,
                                        transformer: transformer,
                                        completion: completion)
                            return
                        default:
                            self.complete(with: task, completion: completion, error: currentError)
                            self.remove(loadTask: task)
                            LGPrint("Error: illegal query disk data result when `optionsInfo.refreshCache` condition")
                            break
                        }
                    }
                } else {
                    self.complete(with: task, completion: completion, error: currentError)
                    self.remove(loadTask: task)
                }
            } else {
                LGPrint("Error: illegal result of download")
            }
        }
    }
    
    private func complete(with task: ImageLoadTask,
                          completion: @escaping ImageManagerCompletionBlock,
                          image: UIImage?,
                          data: Data?,
                          cacheType: ImageCacheType) {
        complete(with: task,
                 completion: completion,
                 image: image,
                 data: data,
                 error: nil,
                 cacheType: cacheType)
    }
    
    private func complete(with task: ImageLoadTask,
                          completion: @escaping ImageManagerCompletionBlock,
                          error: Error) {
        complete(with: task,
                 completion: completion,
                 image: nil,
                 data: nil,
                 error: error,
                 cacheType: .none)
    }
    
    private func complete(with task: ImageLoadTask,
                          completion: @escaping ImageManagerCompletionBlock,
                          image: UIImage?,
                          data: Data?,
                          error: Error?,
                          cacheType: ImageCacheType) {
        DispatchQueue.main.lg.safeAsync { [weak self] in
            guard self != nil, !task.isCancelled else { return }
            completion(image, data, error, cacheType)
        }
    }
}

