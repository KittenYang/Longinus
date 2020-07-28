//
//  BBImageDownloader.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/3.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

public typealias BBImageDownloaderProgress = (Data?, Int, UIImage?) -> Void
public typealias BBImageDownloaderCompletion = (Data?, Error?) -> Void

/// BBImageDownloadTask defines an image download task
public protocol BBImageDownloadTask {
    var sentinel: Int32 { get }
    var url: URL { get }
    var isCancelled: Bool { get }
    var progress: BBImageDownloaderProgress? { get }
    var completion: BBImageDownloaderCompletion { get }
    
    func cancel()
}

/// BBImageDownloader defines downloading and canceling behaviors
public protocol BBImageDownloader: AnyObject {
    /// Downloads image with url and custom options
    ///
    /// - Parameters:
    ///   - url: image url
    ///   - options: options for some behaviors
    ///   - progress: a closure called while image is downloading
    ///   - completion: a closure called when downloading is finished
    /// - Returns: BBImageDownloadTask object
    func downloadImage(with url: URL,
                       options: BBWebImageOptions,
                       progress: BBImageDownloaderProgress?,
                       completion: @escaping BBImageDownloaderCompletion) -> BBImageDownloadTask
    
    /// Cancels image download task
    ///
    /// - Parameter task: task to cancel
    func cancel(task: BBImageDownloadTask)
    
    /// Cancels image download with url
    ///
    /// - Parameter url: url to cancel
    func cancel(url: URL)
    
    /// Cancels all preload tasks
    func cancelPreloading()
    
    /// Cancels all download tasks
    func cancelAll()
}

/// BBImageDefaultDownloadTask is a default image download task
private class BBImageDefaultDownloadTask: BBImageDownloadTask {
    private(set) var sentinel: Int32
    private(set) var url: URL
    private(set) var isCancelled: Bool
    private(set) var progress: BBImageDownloaderProgress?
    private(set) var completion: BBImageDownloaderCompletion
    
    init(sentinel: Int32, url: URL, progress: BBImageDownloaderProgress?, completion: @escaping BBImageDownloaderCompletion) {
        self.sentinel = sentinel
        self.url = url
        self.isCancelled = false
        self.progress = progress
        self.completion = completion
    }
    
    func cancel() { isCancelled = true }
}

/// BBMergeRequestImageDownloader manages download tasks.
/// Download tasks with the same url are merge into one download operation which sending one url request.
public class BBMergeRequestImageDownloader {
    public var donwloadTimeout: TimeInterval
    public weak var imageCoder: BBImageCoder?
    
    /// A closure generating download task.
    /// The closure returns BBImageDefaultDownloadTask by default.
    /// Set this property for custom download task.
    public lazy var generateDownloadTask: (URL, BBImageDownloaderProgress?, @escaping BBImageDownloaderCompletion) -> BBImageDownloadTask = { BBImageDefaultDownloadTask(sentinel: OSAtomicIncrement32(&self.taskSentinel), url: $0, progress: $1, completion: $2) }
    
    /// A closure generating download operation.
    /// The closure returns BBMergeRequestImageDownloadOperation by default.
    /// Set this property for custom download operation.
    public var generateDownloadOperation: (URLRequest, URLSession) -> BBImageDownloadOperation
    
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
    
    private let operationQueue: BBImageDownloadOperationQueue
    private var taskSentinel: Int32
    private var urlOperations: [URL : BBImageDownloadOperation]
    private var preloadTasks: [Int32 : BBImageDownloadTask]
    private var httpHeaders: [String : String]
    private let lock: DispatchSemaphore
    private let sessionConfiguration: URLSessionConfiguration
    private lazy var sessionDelegate: BBImageDownloadSessionDelegate = { BBImageDownloadSessionDelegate(downloader: self) }()
    private lazy var session: URLSession = {
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = 1
        queue.name = "com.Kaibo.BBWebImage.download"
        return URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: queue)
    }()
    
    /// Creates a BBMergeRequestImageDownloader object
    ///
    /// - Parameter sessionConfiguration: url session configuration for sending request
    public init(sessionConfiguration: URLSessionConfiguration) {
        donwloadTimeout = 15
        taskSentinel = 0
        generateDownloadOperation = { BBMergeRequestImageDownloadOperation(request: $0, session: $1) }
        operationQueue = BBImageDownloadOperationQueue()
        operationQueue.maxRunningCount = 6
        urlOperations = [:]
        preloadTasks = [:]
        httpHeaders = ["Accept" : "image/*;q=0.8"]
        lock = DispatchSemaphore(value: 1)
        self.sessionConfiguration = sessionConfiguration
    }
    
    /// Updates HTTP header with value and field
    ///
    /// - Parameters:
    ///   - value: value of HTTP header field to update
    ///   - field: HTTP header field to update
    public func update(value: String?, forHTTPHeaderField field: String) {
        lock.wait()
        httpHeaders[field] = value
        lock.signal()
    }
    
    fileprivate func operation(for url: URL) -> BBImageDownloadOperation? {
        lock.wait()
        let operation = urlOperations[url]
        lock.signal()
        return operation
    }
}

extension BBMergeRequestImageDownloader: BBImageDownloader {
    @discardableResult
    public func downloadImage(with url: URL,
                              options: BBWebImageOptions = .none,
                              progress: BBImageDownloaderProgress? = nil,
                              completion: @escaping BBImageDownloaderCompletion) -> BBImageDownloadTask {
        let task = generateDownloadTask(url, progress, completion)
        lock.wait()
        if options.contains(.preload) { preloadTasks[task.sentinel] = task }
        var operation: BBImageDownloadOperation? = urlOperations[url]
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
            let newOperation = generateDownloadOperation(request, session)
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
    
    public func cancel(task: BBImageDownloadTask) {
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

private class BBImageDownloadSessionDelegate: NSObject, URLSessionTaskDelegate {
    private weak var downloader: BBMergeRequestImageDownloader?
    
    init(downloader: BBMergeRequestImageDownloader) {
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

extension BBImageDownloadSessionDelegate: URLSessionDataDelegate {
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
