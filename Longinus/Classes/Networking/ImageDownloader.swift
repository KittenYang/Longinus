//
//  ImageDownloadable.swift
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

public let LonginusImageErrorDomain: String = "LonginusImageErrorDomain"
public typealias ImageDownloaderProgressBlock = (Data?, _ expectedSize: Int, UIImage?) -> Void
public typealias ImageDownloaderCompletionBlock = (Data?, Error?) -> Void
public typealias ImageManagerCompletionBlock = (UIImage?, Data?, Error?, ImageCacheType) -> Void
public typealias ImagePreloadProgress = (_ successCount: Int, _ finishCount: Int, _ total: Int) -> Void
public typealias ImagePreloadCompletion = (_ successCount: Int, _ total: Int) -> Void

public protocol ImageDownloadInfo {
    var sentinel: Int32 { get }
    var url: URL { get }
    var isCancelled: Bool { get }
    var progress: ImageDownloaderProgressBlock? { get }
    var completion: ImageDownloaderCompletionBlock { get }
    
    func cancel()
}

public protocol ImageDownloadable: AnyObject {
    func downloadImage(with url: URL,
                       options: ImageOptions,
                       progress: ImageDownloaderProgressBlock?,
                       completion: @escaping ImageDownloaderCompletionBlock) -> ImageDownloadInfo
    func cancel(info: ImageDownloadInfo)
    func cancel(url: URL)
    func cancelPreloading()
    func cancelAll()
}

private class ImageDefaultDownload: ImageDownloadInfo {
    private(set) var sentinel: Int32
    private(set) var url: URL
    private(set) var isCancelled: Bool
    private(set) var progress: ImageDownloaderProgressBlock?
    private(set) var completion: ImageDownloaderCompletionBlock
    
    init(sentinel: Int32, url: URL, progress: ImageDownloaderProgressBlock?, completion: @escaping ImageDownloaderCompletionBlock) {
        self.sentinel = sentinel
        self.url = url
        self.isCancelled = false
        self.progress = progress
        self.completion = completion
    }
    
    func cancel() { isCancelled = true }
}

public class ImageDownloader {
    public var donwloadTimeout: TimeInterval
    
    /**
     Weak refrense to imageCoder. Set to `ImageDownloadOperateable`(e.g. ImageDownloadOperation) to progressive coding downloading image.
     */
    public weak var imageCoder: ImageCodeable?

    public lazy var generateDownloadInfo: (URL, ImageDownloaderProgressBlock?, @escaping ImageDownloaderCompletionBlock) -> ImageDownloadInfo = {
        ImageDefaultDownload(sentinel: OSAtomicIncrement32(&self.taskSentinel), url: $0, progress: $1, completion: $2)
    }
    
    public var generateDownloadOperation: (URLRequest, URLSession, ImageOptions) -> ImageDownloadOperateable
    
    public var currentDownloadCount: Int {
        lock.lock()
        let count = urlOperations.count
        lock.unlock()
        return count
    }
    
    public var currentPreloadTaskCount: Int {
        lock.lock()
        let count = preloadInfos.count
        lock.unlock()
        return count
    }
    
    public var maxConcurrentDownloadCount: Int {
        get {
            lock.lock()
            let count = operationQueue.maxRunningCount
            lock.unlock()
            return count
        }
        set {
            lock.lock()
            operationQueue.maxRunningCount = newValue
            lock.unlock()
        }
    }
    
    private let operationQueue: ImageDownloadOperationQueue
    private var taskSentinel: Int32
    private var urlOperations: [URL : ImageDownloadOperateable]
    private var preloadInfos: [Int32 : ImageDownloadInfo]
    private var httpHeaders: [String : String]
    private let lock: DispatchSemaphore
    private let sessionConfiguration: URLSessionConfiguration
    private lazy var sessionDelegate: ImageDownloadSessionDelegate = { ImageDownloadSessionDelegate(downloader: self) }()
    private lazy var session: URLSession = {
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = DispatchQueuePool.fitableMaxQueueCount
        queue.name = "\(LonginusPrefixID).download"
        return URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: queue)
    }()
    
    public init(sessionConfiguration: URLSessionConfiguration) {
        donwloadTimeout = 15
        taskSentinel = 0
        generateDownloadOperation = { ImageDownloadOperation(request: $0, session: $1, options: $2) }
        operationQueue = ImageDownloadOperationQueue()
        urlOperations = [:]
        preloadInfos = [:]
        httpHeaders = ["Accept" : "image/*;q=0.8"]
        lock = DispatchSemaphore(value: 1)
        self.sessionConfiguration = sessionConfiguration
    }
    
    public func update(value: String?, forHTTPHeaderField field: String) {
        lock.lock()
        httpHeaders[field] = value
        lock.unlock()
    }
    
    fileprivate func operation(for url: URL) -> ImageDownloadOperateable? {
        lock.lock()
        let operation = urlOperations[url]
        lock.unlock()
        return operation
    }
    
}

extension ImageDownloader: ImageDownloadable {
    
    @discardableResult
    public func downloadImage(with url: URL,
                              options: ImageOptions = .none,
                              progress: ImageDownloaderProgressBlock? = nil,
                              completion: @escaping ImageDownloaderCompletionBlock) -> ImageDownloadInfo {
        let info = generateDownloadInfo(url, progress, completion)
        lock.lock()
        if options.contains(.preload) { preloadInfos[info.sentinel] = info }
        var operation: ImageDownloadOperateable? = urlOperations[url]
        if operation != nil {
            if !options.contains(.preload) {
                operationQueue.upgradePreloadOperation(for: url)
            }
        } else {
            let timeout = donwloadTimeout > 0 ? donwloadTimeout : 15
            let cachePolicy: URLRequest.CachePolicy = options.contains(.useURLCache) ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData
            var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
            request.httpShouldHandleCookies = options.contains(.handleCookies)
            request.allHTTPHeaderFields = httpHeaders
            request.httpShouldUsePipelining = true
            let newOperation = generateDownloadOperation(request, session, options)
            if options.contains(.progressiveDownload) || options.contains(.progressiveBlur) { newOperation.imageCoder = imageCoder }
            newOperation.completion = { [weak self, weak newOperation] in
                guard let self = self else { return }
                self.lock.lock()
                self.urlOperations.removeValue(forKey: url)
                if let infos = newOperation?.downloadInfos {
                    for info in infos { self.preloadInfos.removeValue(forKey: info.sentinel) }
                }
                self.operationQueue.removeOperation(forKey: url)
                self.lock.unlock()
            }
            urlOperations[url] = newOperation
            operationQueue.add(newOperation, preload: options.contains(.preload))
            operation = newOperation
        }
        operation?.add(info: info)
        lock.unlock()
        return info
    }
    
    public func cancel(info: ImageDownloadInfo) {
        info.cancel()
        lock.lock()
        let operation = urlOperations[info.url]
        lock.unlock()
        if let operation = operation {
            var allCancelled = true
            let infos = operation.downloadInfos
            for info in infos where !info.isCancelled {
                allCancelled = false
                break
            }
            if allCancelled { operation.cancel() }
        }
    }
    
    public func cancel(url: URL) {
        lock.lock()
        let operation = urlOperations[url]
        lock.unlock()
        operation?.cancel()
    }
    
    public func cancelPreloading() {
        lock.lock()
        let infos = preloadInfos
        lock.unlock()
        for (_, info) in infos {
            cancel(info: info)
        }
    }
    
    public func cancelAll() {
        self.lock.lock()
        let operations = urlOperations
        self.lock.unlock()
        for (_, operation) in operations {
            operation.cancel()
        }
    }
    
}


private class ImageDownloadSessionDelegate: NSObject, URLSessionTaskDelegate {
    private weak var downloader: ImageDownloader?
    
    init(downloader: ImageDownloader) {
        self.downloader = downloader
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let url = task.originalRequest?.url,
            let operation = downloader?.operation(for: url),
            operation.dataTaskId == task.taskIdentifier,
            let taskDelegate = operation as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, task: task, didCompleteWithError: error)
        }
    }
}

extension ImageDownloadSessionDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let url = dataTask.originalRequest?.url,
            let operation = downloader?.operation(for: url),
            operation.dataTaskId == dataTask.taskIdentifier,
            let dataDelegate = operation as? URLSessionDataDelegate {
            dataDelegate.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
        } else {
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let url = dataTask.originalRequest?.url,
            let operation = downloader?.operation(for: url),
            operation.dataTaskId == dataTask.taskIdentifier,
            let dataDelegate = operation as? URLSessionDataDelegate {
            dataDelegate.urlSession?(session, dataTask: dataTask, didReceive: data)
        }
    }
}
