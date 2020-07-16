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
public typealias ImageDownloaderProgressBlock = (Data?, Int, UIImage?) -> Void
public typealias ImageDownloaderCompletionBlock = (Data?, Error?) -> Void
public typealias ImageManagerCompletionBlock = (UIImage?, Data?, Error?, ImageCacheType) -> Void
public typealias ImagePreloadProgress = (_ successCount: Int, _ finishCount: Int, _ total: Int) -> Void
public typealias ImagePreloadCompletion = (_ successCount: Int, _ total: Int) -> Void

public protocol ImageDownloadTaskable {
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
                       completion: @escaping ImageDownloaderCompletionBlock) -> ImageDownloadTaskable
    func cancel(task: ImageDownloadTaskable)
    func cancel(url: URL)
    func cancelPreloading()
    func cancelAll()
}

private class ImageDefaultDownloadTask: ImageDownloadTaskable {
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
    public weak var imageCoder: ImageCodeable?

    public lazy var generateDownloadTask: (URL, ImageDownloaderProgressBlock?, @escaping ImageDownloaderCompletionBlock) -> ImageDownloadTaskable = {
        ImageDefaultDownloadTask(sentinel: OSAtomicIncrement32(&self.taskSentinel), url: $0, progress: $1, completion: $2)
    }
    
    public var generateDownloadOperation: (URLRequest, URLSession, ImageOptions) -> ImageDownloadOperateable
    
    public var currentDownloadCount: Int {
        lock.wait()
        let count = urlOperations.count
        lock.signal()
        return count
    }
    
    public var currentPreloadTaskCount: Int {
        lock.wait()
        let count = preloadTasks.count
        lock.signal()
        return count
    }
    
    public var maxConcurrentDownloadCount: Int {
        get {
            lock.wait()
            let count = operationQueue.maxRunningCount
            lock.signal()
            return count
        }
        set {
            lock.wait()
            operationQueue.maxRunningCount = newValue
            lock.signal()
        }
    }
    
    private let operationQueue: ImageDownloadOperationQueue
    private var taskSentinel: Int32
    private var urlOperations: [URL : ImageDownloadOperateable]
    private var preloadTasks: [Int32 : ImageDownloadTaskable]
    private var httpHeaders: [String : String]
    private let lock: DispatchSemaphore
    private let sessionConfiguration: URLSessionConfiguration
    private lazy var sessionDelegate: ImageDownloadSessionDelegate = { ImageDownloadSessionDelegate(downloader: self) }()
    private lazy var session: URLSession = {
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = 1
        queue.name = "\(LonginusPrefixID).download"
        return URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: queue)
    }()
    
    public init(sessionConfiguration: URLSessionConfiguration) {
        donwloadTimeout = 15
        taskSentinel = 0
        generateDownloadOperation = { ImageDownloadOperation(request: $0, session: $1, options: $2) }
        operationQueue = ImageDownloadOperationQueue()
        operationQueue.maxRunningCount = 6
        urlOperations = [:]
        preloadTasks = [:]
        httpHeaders = ["Accept" : "image/*;q=0.8"]
        lock = DispatchSemaphore(value: 1)
        self.sessionConfiguration = sessionConfiguration
    }
    
    public func update(value: String?, forHTTPHeaderField field: String) {
        lock.wait()
        httpHeaders[field] = value
        lock.signal()
    }
    
    fileprivate func operation(for url: URL) -> ImageDownloadOperateable? {
        lock.wait()
        let operation = urlOperations[url]
        lock.signal()
        return operation
    }
    
}

extension ImageDownloader: ImageDownloadable {
    
    @discardableResult
    public func downloadImage(with url: URL,
                              options: ImageOptions = .none,
                              progress: ImageDownloaderProgressBlock? = nil,
                              completion: @escaping ImageDownloaderCompletionBlock) -> ImageDownloadTaskable {
        let task = generateDownloadTask(url, progress, completion)
        lock.wait()
        if options.contains(.preload) { preloadTasks[task.sentinel] = task }
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
            if options.contains(.progressiveDownload) { newOperation.imageCoder = imageCoder }
            newOperation.completion = { [weak self, weak newOperation] in
                guard let self = self else { return }
                self.lock.wait()
                self.urlOperations.removeValue(forKey: url)
                if let tasks = newOperation?.downloadTasks {
                    for task in tasks { self.preloadTasks.removeValue(forKey: task.sentinel) }
                }
                self.operationQueue.removeOperation(forKey: url)
                self.lock.signal()
            }
            urlOperations[url] = newOperation
            operationQueue.add(newOperation, preload: options.contains(.preload))
            operation = newOperation
        }
        operation?.add(task: task)
        lock.signal()
        return task
    }
    
    public func cancel(task: ImageDownloadTaskable) {
        task.cancel()
        lock.wait()
        let operation = urlOperations[task.url]
        lock.signal()
        if let operation = operation {
            var allCancelled = true
            let tasks = operation.downloadTasks
            for task in tasks where !task.isCancelled {
                allCancelled = false
                break
            }
            if allCancelled { operation.cancel() }
        }
    }
    
    public func cancel(url: URL) {
        lock.wait()
        let operation = urlOperations[url]
        lock.signal()
        operation?.cancel()
    }
    
    public func cancelPreloading() {
        lock.wait()
        let tasks = preloadTasks
        lock.signal()
        for (_, task) in tasks {
            cancel(task: task)
        }
    }
    
    public func cancelAll() {
        self.lock.wait()
        let operations = urlOperations
        self.lock.signal()
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
