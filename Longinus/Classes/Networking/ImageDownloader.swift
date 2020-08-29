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

/**
 Represents download web image abilities
 */
public protocol ImageDownloadable: AnyObject {
    /**
     Download image from url with options, this method will return a `ImageDefaultDownload` object immediately. The request result will return in completion handler. Progress handler will be invoked if not nil.
     
     - Parameters:
        - url: The image url
        - options: The image download Options
        - progress: The image download progress handler
        - completion: The image download completion handler
     */
    func downloadImage(with url: URL,
                       options: LonginusImageOptions?,
                       progress: ImageDownloaderProgressBlock?,
                       completion: @escaping ImageDownloaderCompletionBlock) -> ImageDefaultDownload
    
    /**
     Cancel a image download
     - Parameters:
        - download: The downlaod will be cancelled
     */
    func cancel(download: ImageDefaultDownload)
    
    /**
     Cancel a image download by specific url
     - Parameters:
        - url: The image url wil be cancelled
     */
    func cancel(url: URL)
    
    /**
     Cancel preloading download
     */
    func cancelPreloading()
    
    /**
     Cancel all operations(URLSessionTask insided)
     */
    func cancelAll()
}

public class ImageDefaultDownload {
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
    
    /// The duration before the downloading is timeout. Default is 15 seconds.
    public var donwloadTimeout: TimeInterval
    
    /// Whether the download requests should use pipeline or not. Default is true.
    public var requestsUsePipelining = true
    
    /**
     Weak refrense to imageCoder. Set to `ImageDownloadOperateable`(e.g. ImageDownloadOperation) to progressive coding downloading image.
     */
    public weak var imageCoder: ImageCodeable?

    /**
     Lazy var to generate `ImageDefaultDownload`
     */
    public lazy var generateDownload: (URL, ImageDownloaderProgressBlock?, @escaping ImageDownloaderCompletionBlock) -> ImageDefaultDownload = {
        ImageDefaultDownload(sentinel: OSAtomicIncrement32(&self.taskSentinel), url: $0, progress: $1, completion: $2)
    }
    
    /**
     Lazy var to generate `ImageDownloadOperation`
     */
    public lazy var generateDownloadOperation: (URLRequest, URLSession, LonginusImageOptions?) -> ImageDownloadOperateable = {
        ImageDownloadOperation(request: $0, session: $1, options: $2)
    }
    
    /**
     Get current download count
     */
    public var currentDownloadCount: Int {
        lock.lock()
        let count = urlOperations.count
        lock.unlock()
        return count
    }
    
    /**
     Get current preload download count
     */
    public var currentPreloadTaskCount: Int {
        lock.lock()
        let count = preloadDownloads.count
        lock.unlock()
        return count
    }
    
    /**
     Get current max concurrent download count
     */
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
    
    /// Use this to set supply a configuration for the downloader. By default,
    /// NSURLSessionConfiguration.ephemeralSessionConfiguration() will be used.
    ///
    /// You could change the configuration before a downloading task starts.
    /// A configuration without persistent storage for caches is requested for downloader working correctly.
    open var sessionConfiguration: URLSessionConfiguration {
        didSet {
            session.invalidateAndCancel()
            session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: getSessionQueue())
        }
    }
    
    /**
     A set of trusted hosts when receiving server trust challenges. A challenge with host name contained in this
     set will be ignored. You can use this set to specify the self-signed site.
     */
    open var trustedHosts: Set<String>?
    
    /**
     A responder for authentication challenge.
     Downloader will forward the received authentication challenge for the downloading session to this responder.
     */
    open weak var authenticationChallengeResponder: AuthenticationChallengeResponsable?
    
    private let operationQueue: ImageDownloadOperationQueue
    private var taskSentinel: Int32
    private var urlOperations: [URL : ImageDownloadOperateable]
    private var preloadDownloads: [Int32 : ImageDefaultDownload]
    private var httpHeaders: [String : String]
    private let lock: DispatchSemaphore
    private lazy var sessionDelegate: ImageDownloadSessionDelegate = { ImageDownloadSessionDelegate(downloader: self) }()
    private lazy var session: URLSession = {
        return URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: getSessionQueue())
    }()
    private func getSessionQueue() -> OperationQueue {
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = 1//DispatchQueuePool.fitableMaxQueueCount
        queue.name = "\(LonginusPrefixID).download"
        return queue
    }
    
    public init(sessionConfiguration: URLSessionConfiguration) {
        self.sessionConfiguration = sessionConfiguration
        donwloadTimeout = 15
        taskSentinel = 0
        operationQueue = ImageDownloadOperationQueue()
        urlOperations = [:]
        preloadDownloads = [:]
        httpHeaders = ["Accept" : "image/*;q=0.8"] // @"image/webp,image/*;q=0.8"
        lock = DispatchSemaphore(value: 1)
        authenticationChallengeResponder = self
    }
        
    func operation(for url: URL) -> ImageDownloadOperateable? {
        lock.lock()
        let operation = urlOperations[url]
        lock.unlock()
        return operation
    }
    
}

extension ImageDownloader: ImageDownloadable {
    
    @discardableResult
    public func downloadImage(with url: URL,
                              options: LonginusImageOptions? = nil,
                              progress: ImageDownloaderProgressBlock? = nil,
                              completion: @escaping ImageDownloaderCompletionBlock) -> ImageDefaultDownload {
        let download = generateDownload(url, progress, completion)
        let optionsInfo = LonginusParsedImageOptionsInfo(options)
        lock.lock()
        if optionsInfo.preload { preloadDownloads[download.sentinel] = download }
        var operation: ImageDownloadOperateable? = urlOperations[url]
        if operation != nil {
            if !optionsInfo.preload {
                operationQueue.upgradePreloadOperation(for: url)
            }
        } else {
            let timeout = donwloadTimeout > 0 ? donwloadTimeout : 15
            let cachePolicy: URLRequest.CachePolicy = optionsInfo.useURLCache ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData
            var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
            request.httpShouldHandleCookies = optionsInfo.handleCookies
            request.allHTTPHeaderFields = httpHeaders
            request.httpShouldUsePipelining = requestsUsePipelining
            
            if let httpHeadersModifier = optionsInfo.httpHeadersModifier {
                if let newHeaders = httpHeadersModifier.modified(for: request.allHTTPHeaderFields) {
                    request.allHTTPHeaderFields = newHeaders
                }
            }
            
            if let requestModifier = optionsInfo.requestModifier {
                // Modifies request before sending.
                guard let r = requestModifier.modified(for: request) else {
                    completion(nil, NSError(domain: LonginusImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "empty request"]))
                    lock.unlock()
                    return download
                }
                request = r
            }
            
            // There is a possibility that request modifier changed the url to `nil` or empty.
            // In this case, throw an error.
            guard let url = request.url, !url.absoluteString.isEmpty else {
                completion(nil, NSError(domain: LonginusImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "invalid URL"]))
                lock.unlock()
                return download
            }
            
            let newOperation = generateDownloadOperation(request, session, options)
            if optionsInfo.progressiveDownload || optionsInfo.progressiveBlur { newOperation.imageCoder = imageCoder }
            newOperation.completion = { [weak self, weak newOperation] in
                guard let self = self else { return }
                self.lock.lock()
                self.urlOperations.removeValue(forKey: url)
                if let infos = newOperation?.downloads {
                    for info in infos { self.preloadDownloads.removeValue(forKey: info.sentinel) }
                }
                self.operationQueue.removeOperation(forKey: url)
                self.lock.unlock()
            }
            urlOperations[url] = newOperation
            operationQueue.add(newOperation, preload: optionsInfo.preload)
            operation = newOperation
        }
        operation?.add(download: download)
        lock.unlock()
        return download
    }
    
    public func cancel(download: ImageDefaultDownload) {
        download.cancel()
        lock.lock()
        let operation = urlOperations[download.url]
        lock.unlock()
        if let operation = operation {
            var allCancelled = true
            let infos = operation.downloads
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
        let downloads = preloadDownloads
        lock.unlock()
        for (_, info) in downloads {
            cancel(download: info)
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

// Use the default implementation from extension of `AuthenticationChallengeResponsable`.
extension ImageDownloader: AuthenticationChallengeResponsable {}
