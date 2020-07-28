//
//  BBWebImageManager.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/3.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

/// BBWebImageOptions controls some behaviors of image downloading, caching, decoding and displaying
public struct BBWebImageOptions: OptionSet {
    public let rawValue: Int
    
    /// Default behavior
    public static let none = BBWebImageOptions(rawValue: 0)
    
    /// Query image data when memory image is gotten
    public static let queryDataWhenInMemory = BBWebImageOptions(rawValue: 1 << 0)
    
    /// Do not use image disk cache
    public static let ignoreDiskCache = BBWebImageOptions(rawValue: 1 << 1)
    
    /// Download image and update cache
    public static let refreshCache = BBWebImageOptions(rawValue: 1 << 2)
    
    /// Retry to download even the url is blacklisted for failed downloading
    public static let retryFailedUrl = BBWebImageOptions(rawValue: 1 << 3)
    
    /// URLRequest.cachePolicy = .useProtocolCachePolicy
    public static let useURLCache = BBWebImageOptions(rawValue: 1 << 4)
    
    /// URLRequest.httpShouldHandleCookies = true
    public static let handleCookies = BBWebImageOptions(rawValue: 1 << 5)
    
    /// Image is displayed progressively when downloading
    public static let progressiveDownload = BBWebImageOptions(rawValue: 1 << 6)
    
    /// Do not display placeholder image
    public static let ignorePlaceholder = BBWebImageOptions(rawValue: 1 << 7)
    
    /// Do not decode image
    public static let ignoreImageDecoding = BBWebImageOptions(rawValue: 1 << 8)
    
    /// Preload image data and cache to disk
    internal static let preload = BBWebImageOptions(rawValue: 1 << 32)
    
    public init(rawValue: Int) { self.rawValue = rawValue }
}

public let BBWebImageErrorDomain: String = "BBWebImageErrorDomain"
public typealias BBWebImageManagerCompletion = (UIImage?, Data?, Error?, BBImageCacheType) -> Void
public typealias BBWebImagePreloadProgress = (_ successCount: Int, _ finishCount: Int, _ total: Int) -> Void
public typealias BBWebImagePreloadCompletion = (_ successCount: Int, _ total: Int) -> Void

/// BBWebImageLoadTask defines an image loading task
public class BBWebImageLoadTask: NSObject { // If not subclass NSObject, there is memory leak (unknown reason)
    public var isCancelled: Bool {
        pthread_mutex_lock(&lock)
        let c = cancelled
        pthread_mutex_unlock(&lock)
        return c
    }
    public let sentinel: Int32
    private var cancelled: Bool
    private var lock: pthread_mutex_t
    fileprivate var downloadTask: BBImageDownloadTask?
    fileprivate weak var imageManager: BBWebImageManager?
    
    init(sentinel: Int32) {
        self.sentinel = sentinel
        cancelled = false
        lock = pthread_mutex_t()
        pthread_mutex_init(&lock, nil)
    }
    
    /// Cancels current image loading task
    public func cancel() {
        pthread_mutex_lock(&lock)
        if cancelled {
            pthread_mutex_unlock(&lock)
            return
        }
        cancelled = true
        pthread_mutex_unlock(&lock)
        if let task = downloadTask,
            let downloader = imageManager?.imageDownloader {
            downloader.cancel(task: task)
        }
        imageManager?.remove(loadTask: self)
    }
    
    public static func == (lhs: BBWebImageLoadTask, rhs: BBWebImageLoadTask) -> Bool {
        return lhs.sentinel == rhs.sentinel
    }
    
    public override var hash: Int {
        return Int(sentinel)
    }
}

/// BBWebImageManager downloads and caches image asynchronously
public class BBWebImageManager {
    /// BBWebImageManager shared instance
    public static let shared: BBWebImageManager = { () -> BBWebImageManager in
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! + "/com.Kaibo.BBWebImage"
        return BBWebImageManager(cachePath: path, sizeThreshold: 20 * 1024)
    }()
    
    public private(set) var imageCache: BBImageCache
    public private(set) var imageDownloader: BBImageDownloader
    public private(set) var imageCoder: BBImageCoder
    private let coderQueue: BBDispatchQueuePool
    private var tasks: Set<BBWebImageLoadTask>
    private var preloadTasks: Set<BBWebImageLoadTask>
    private var taskLock: pthread_mutex_t
    private var taskSentinel: Int32
    private var urlBlacklist: Set<URL>
    private var urlBlacklistLock: pthread_mutex_t
    
    public var currentTaskCount: Int {
        pthread_mutex_lock(&taskLock)
        let c = tasks.count
        pthread_mutex_unlock(&taskLock)
        return c
    }
    
    public var currentPreloadTaskCount: Int {
        pthread_mutex_lock(&taskLock)
        let c = preloadTasks.count
        pthread_mutex_unlock(&taskLock)
        return c
    }
    
    /// Creates a BBWebImageManager object with default image cache, downloader and coder
    ///
    /// - Parameters:
    ///   - cachePath: directory storing image data
    ///   - sizeThreshold: threshold specifying image data is store in sqlite (data.count <= threshold) or file (data.count > threshold)
    public convenience init(cachePath: String, sizeThreshold: Int) {
        let cache = BBLRUImageCache(path: cachePath, sizeThreshold: sizeThreshold)
        let downloader = BBMergeRequestImageDownloader(sessionConfiguration: .default)
        let coder = BBImageCoderManager()
        cache.imageCoder = coder
        downloader.imageCoder = coder
        self.init(cache: cache, downloader: downloader, coder: coder)
    }
    
    /// Creates a BBWebImageManager object with image cache, downloader and coder
    ///
    /// - Parameters:
    ///   - cache: cache conforming to BBImageCache
    ///   - downloader: downloader conforming to BBImageDownloader
    ///   - coder: coder conforming to BBImageCoder
    public init(cache: BBImageCache, downloader: BBImageDownloader, coder: BBImageCoder) {
        imageCache = cache
        imageDownloader = downloader
        imageCoder = coder
        coderQueue = BBDispatchQueuePool.userInitiated
        tasks = Set()
        preloadTasks = Set()
        taskSentinel = 0
        taskLock = pthread_mutex_t()
        pthread_mutex_init(&taskLock, nil)
        urlBlacklist = Set()
        urlBlacklistLock = pthread_mutex_t()
        pthread_mutex_init(&urlBlacklistLock, nil)
    }
    
    /// Gets image from cache or downloads image
    ///
    /// - Parameters:
    ///   - resource: image resource specifying how to download and cache image
    ///   - options: options for some behaviors
    ///   - editor: editor specifying how to edit and cache image in memory
    ///   - progress: a closure called while image is downloading
    ///   - completion: a closure called when image loading is finished
    /// - Returns: BBWebImageLoadTask object
    @discardableResult
    public func loadImage(with resource: BBWebCacheResource,
                          options: BBWebImageOptions = .none,
                          editor: BBWebImageEditor? = nil,
                          progress: BBImageDownloaderProgress? = nil,
                          completion: @escaping BBWebImageManagerCompletion) -> BBWebImageLoadTask {
        let task = newLoadTask()
        pthread_mutex_lock(&taskLock)
        tasks.insert(task)
        if options.contains(.preload) { preloadTasks.insert(task) }
        pthread_mutex_unlock(&taskLock)
        
        if !options.contains(.retryFailedUrl) {
            pthread_mutex_lock(&urlBlacklistLock)
            let inBlacklist = urlBlacklist.contains(resource.downloadUrl)
            pthread_mutex_unlock(&urlBlacklistLock)
            
            if inBlacklist {
                complete(with: task, completion: completion, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: [NSLocalizedDescriptionKey : "URL is blacklisted"]))
                remove(loadTask: task)
                return task
            }
        }
        
        if options.contains(.refreshCache) {
            downloadImage(with: resource,
                          options: options,
                          task: task,
                          editor: editor,
                          progress: progress,
                          completion: completion)
            return task
        }
        
        // Get memory image
        var memoryImage: UIImage?
        imageCache.image(forKey: resource.cacheKey, cacheType: .memory) { (result: BBImageCacheQueryCompletionResult) in
            switch result {
            case let .memory(image: image):
                memoryImage = image
            default:
                break
            }
        }
        var finished = false
        if let currentImage = memoryImage {
            if options.contains(.preload) {
                complete(with: task,
                         completion: completion,
                         image: currentImage,
                         data: nil,
                         cacheType: .memory)
                remove(loadTask: task)
                finished = true
            } else if !options.contains(.queryDataWhenInMemory) {
                if let animatedImage = currentImage as? BBAnimatedImage {
                    animatedImage.bb_editor = editor
                    complete(with: task,
                             completion: completion,
                             image: animatedImage,
                             data: nil,
                             cacheType: .memory)
                    remove(loadTask: task)
                    finished = true
                } else if let currentEditor = editor {
                    if currentEditor.key == currentImage.bb_imageEditKey {
                        complete(with: task,
                                 completion: completion,
                                 image: currentImage,
                                 data: nil,
                                 cacheType: .memory)
                        remove(loadTask: task)
                        finished = true
                    } else if currentImage.bb_imageEditKey == nil {
                        coderQueue.async { [weak self, weak task] in
                            guard let self = self, let task = task, !task.isCancelled else { return }
                            if let image = currentEditor.edit(currentImage) {
                                guard !task.isCancelled else { return }
                                image.bb_imageEditKey = currentEditor.key
                                image.bb_imageFormat = currentImage.bb_imageFormat
                                self.complete(with: task,
                                              completion: completion,
                                              image: image,
                                              data: nil,
                                              cacheType: .memory)
                                self.imageCache.store(image,
                                                      data: nil,
                                                      forKey: resource.cacheKey,
                                                      cacheType: .memory,
                                                      completion: nil)
                            } else {
                                self.complete(with: task, completion: completion, error: NSError(domain: BBWebImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "No edited image"]))
                            }
                            self.remove(loadTask: task)
                        }
                        finished = true
                    }
                } else if currentImage.bb_imageEditKey == nil {
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
        
        if options.contains(.ignoreDiskCache) || resource.downloadUrl.isFileURL {
            downloadImage(with: resource,
                          options: options.union(.ignoreDiskCache),
                          task: task,
                          editor: editor,
                          progress: progress,
                          completion: completion)
        } else if options.contains(.preload) {
            // Check whether disk data exists
            imageCache.diskDataExists(forKey: resource.cacheKey) { (exists) in
                if exists {
                    self.complete(with: task,
                                  completion: completion,
                                  image: nil,
                                  data: nil,
                                  cacheType: .disk)
                    self.remove(loadTask: task)
                } else {
                    self.downloadImage(with: resource,
                                       options: options,
                                       task: task,
                                       editor: editor,
                                       progress: progress,
                                       completion: completion)
                }
            }
        } else {
            // Get disk data
            imageCache.image(forKey: resource.cacheKey, cacheType: .disk) { [weak self, weak task] (result: BBImageCacheQueryCompletionResult) in
                guard let self = self, let task = task, !task.isCancelled else { return }
                switch result {
                case let .disk(data: data):
                    self.handle(imageData: data,
                                options: options,
                                cacheType: (memoryImage != nil ? .all : .disk),
                                forTask: task,
                                resource: resource,
                                editor: editor,
                                completion: completion)
                case .none:
                    // Download
                    self.downloadImage(with: resource,
                                       options: options,
                                       task: task,
                                       editor: editor,
                                       progress: progress,
                                       completion: completion)
                default:
                    print("Error: illegal query disk data result")
                    break
                }
            }
        }
        return task
    }
    
    /// Preloads image from network if not in cache.
    /// This method checks cache, downloads image data and stores data to disk, without storing to memory, decoding or editing.
    /// Any previous preloading tasks are cancelled.
    ///
    /// - Parameters:
    ///   - resources: image resources specifying how to download and cache image
    ///   - options: options for some behaviors
    ///   - progress: a closure called while images are loading
    ///   - completion: a closure called when image loading is finished
    /// - Returns: BBWebImageLoadTask array
    @discardableResult
    public func preload(_ resources: [BBWebCacheResource],
                        options: BBWebImageOptions = .none,
                        progress: BBWebImagePreloadProgress? = nil,
                        completion: BBWebImagePreloadCompletion? = nil) -> [BBWebImageLoadTask] {
        cancelPreloading()
        let total = resources.count
        if total <= 0 { return [] }
        var finishCount = 0
        var successCount = 0
        var tasks: [BBWebImageLoadTask] = []
        for resource in resources {
            var currentOptions: BBWebImageOptions = .preload
            if options.contains(.useURLCache) { currentOptions.insert(.useURLCache) }
            if options.contains(.handleCookies) { currentOptions.insert(.handleCookies) }
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
    
    /// Cancels image preloading tasks
    public func cancelPreloading() {
        pthread_mutex_lock(&taskLock)
        let currentTasks = preloadTasks
        pthread_mutex_unlock(&taskLock)
        for task in currentTasks {
            task.cancel()
        }
    }
    
    /// Cancels all image loading tasks
    public func cancelAll() {
        pthread_mutex_lock(&taskLock)
        let currentTasks = tasks
        pthread_mutex_unlock(&taskLock)
        for task in currentTasks {
            task.cancel()
        }
    }
    
    private func newLoadTask() -> BBWebImageLoadTask {
        let task = BBWebImageLoadTask(sentinel: OSAtomicIncrement32(&taskSentinel))
        task.imageManager = self
        return task
    }
    
    fileprivate func remove(loadTask: BBWebImageLoadTask) {
        pthread_mutex_lock(&taskLock)
        tasks.remove(loadTask)
        preloadTasks.remove(loadTask)
        pthread_mutex_unlock(&taskLock)
    }
    
    private func handle(imageData data: Data,
                        options: BBWebImageOptions,
                        cacheType: BBImageCacheType,
                        forTask task: BBWebImageLoadTask,
                        resource: BBWebCacheResource,
                        editor: BBWebImageEditor?,
                        completion: @escaping BBWebImageManagerCompletion) {
        if options.contains(.preload) {
            complete(with: task,
                     completion: completion,
                     image: nil,
                     data: data,
                     cacheType: cacheType)
            if cacheType == .none {
                imageCache.store(nil,
                                 data: data,
                                 forKey: resource.cacheKey,
                                 cacheType: .disk,
                                 completion: nil)
            }
            remove(loadTask: task)
            return
        }
        self.coderQueue.async { [weak self, weak task] in
            guard let self = self, let task = task, !task.isCancelled else { return }
            let decodedImage = self.imageCoder.decodedImage(with: data)
            if let currentEditor = editor {
                if let animatedImage = decodedImage as? BBAnimatedImage {
                    animatedImage.bb_editor = currentEditor
                    self.complete(with: task,
                                  completion: completion,
                                  image: animatedImage,
                                  data: data,
                                  cacheType: cacheType)
                    let storeCacheType: BBImageCacheType = (cacheType == .disk || options.contains(.ignoreDiskCache) ? .memory : .all)
                    self.imageCache.store(animatedImage,
                                          data: data,
                                          forKey: resource.cacheKey,
                                          cacheType: storeCacheType,
                                          completion: nil)
                } else if let inputImage = decodedImage {
                    if let image = currentEditor.edit(inputImage) {
                        guard !task.isCancelled else { return }
                        image.bb_imageEditKey = currentEditor.key
                        image.bb_imageFormat = data.bb_imageFormat
                        self.complete(with: task,
                                      completion: completion,
                                      image: image,
                                      data: data,
                                      cacheType: cacheType)
                        let storeCacheType: BBImageCacheType = (cacheType == .disk || options.contains(.ignoreDiskCache) ? .memory : .all)
                        self.imageCache.store(image,
                                              data: data,
                                              forKey: resource.cacheKey,
                                              cacheType: storeCacheType,
                                              completion: nil)
                    } else {
                        self.complete(with: task, completion: completion, error: NSError(domain: BBWebImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "No edited image"]))
                    }
                } else {
                    if cacheType == .none {
                        pthread_mutex_lock(&self.urlBlacklistLock)
                        self.urlBlacklist.insert(resource.downloadUrl)
                        pthread_mutex_unlock(&self.urlBlacklistLock)
                    }
                    self.complete(with: task, completion: completion, error: NSError(domain: BBWebImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Invalid image data"]))
                }
            } else if var image = decodedImage {
                if !options.contains(.ignoreImageDecoding),
                    let decompressedImage = self.imageCoder.decompressedImage(with: image, data: data) {
                    image = decompressedImage
                }
                self.complete(with: task,
                              completion: completion,
                              image: image,
                              data: data,
                              cacheType: cacheType)
                let storeCacheType: BBImageCacheType = (cacheType == .disk || options.contains(.ignoreDiskCache) ? .memory : .all)
                self.imageCache.store(image,
                                      data: data,
                                      forKey: resource.cacheKey,
                                      cacheType: storeCacheType,
                                      completion: nil)
            } else {
                if cacheType == .none {
                    pthread_mutex_lock(&self.urlBlacklistLock)
                    self.urlBlacklist.insert(resource.downloadUrl)
                    pthread_mutex_unlock(&self.urlBlacklistLock)
                }
                self.complete(with: task, completion: completion, error: NSError(domain: BBWebImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Invalid image data"]))
            }
            self.remove(loadTask: task)
        }
    }
    
    private func downloadImage(with resource: BBWebCacheResource,
                               options: BBWebImageOptions,
                               task: BBWebImageLoadTask,
                               editor: BBWebImageEditor?,
                               progress: BBImageDownloaderProgress?,
                               completion: @escaping BBWebImageManagerCompletion) {
        task.downloadTask = self.imageDownloader.downloadImage(with: resource.downloadUrl, options: options, progress: progress) { [weak self, weak task] (data: Data?, error: Error?) in
            guard let self = self, let task = task, !task.isCancelled else { return }
            if let currentData = data {
                if options.contains(.retryFailedUrl) {
                    pthread_mutex_lock(&self.urlBlacklistLock)
                    self.urlBlacklist.remove(resource.downloadUrl)
                    pthread_mutex_unlock(&self.urlBlacklistLock)
                }
                self.handle(imageData: currentData,
                            options: options,
                            cacheType: .none,
                            forTask: task,
                            resource: resource,
                            editor: editor,
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
                    pthread_mutex_lock(&self.urlBlacklistLock)
                    self.urlBlacklist.insert(resource.downloadUrl)
                    pthread_mutex_unlock(&self.urlBlacklistLock)
                }
                
                self.complete(with: task, completion: completion, error: currentError)
                self.remove(loadTask: task)
            } else {
                print("Error: illegal result of download")
            }
        }
    }
    
    private func complete(with task: BBWebImageLoadTask,
                          completion: @escaping BBWebImageManagerCompletion,
                          image: UIImage?,
                          data: Data?,
                          cacheType: BBImageCacheType) {
        complete(with: task,
                 completion: completion,
                 image: image,
                 data: data,
                 error: nil,
                 cacheType: cacheType)
    }
    
    private func complete(with task: BBWebImageLoadTask, completion: @escaping BBWebImageManagerCompletion, error: Error) {
        complete(with: task,
                 completion: completion,
                 image: nil,
                 data: nil,
                 error: error,
                 cacheType: .none)
    }
    
    private func complete(with task: BBWebImageLoadTask,
                          completion: @escaping BBWebImageManagerCompletion,
                          image: UIImage?,
                          data: Data?,
                          error: Error?,
                          cacheType: BBImageCacheType) {
        DispatchQueue.main.bb_safeAsync { [weak self] in
            guard self != nil, !task.isCancelled else { return }
            completion(image, data, error, cacheType)
        }
    }
}
