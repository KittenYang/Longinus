//
//  BBWebCache.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/12/7.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

public typealias BBSetImage = (UIImage?) -> Void

private var webCacheOperationKey: Void?

/// BBWebCache defines image loading, editing and setting behaivors
public protocol BBWebCache: AnyObject {
    func bb_setImage(with resource: BBWebCacheResource,
                     placeholder: UIImage?,
                     options: BBWebImageOptions,
                     editor: BBWebImageEditor?,
                     taskKey: String,
                     setImage: @escaping BBSetImage,
                     progress: BBImageDownloaderProgress?,
                     completion: BBWebImageManagerCompletion?)
}

/// BBWebCacheOperation contains image loading tasks (BBWebImageLoadTask) for BBWebCache object
public class BBWebCacheOperation {
    private let weakTaskMap: NSMapTable<NSString, BBWebImageLoadTask>
    private var downloadProgressDic: [String : Double]
    private var lock: pthread_mutex_t
    
    public init() {
        weakTaskMap = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        downloadProgressDic = [:]
        lock = pthread_mutex_t()
        pthread_mutex_init(&lock, nil)
    }
    
    public func task(forKey key: String) -> BBWebImageLoadTask? {
        pthread_mutex_lock(&lock)
        let task = weakTaskMap.object(forKey: key as NSString)
        pthread_mutex_unlock(&lock)
        return task
    }
    
    public func setTask(_ task: BBWebImageLoadTask, forKey key: String) {
        pthread_mutex_lock(&lock)
        weakTaskMap.setObject(task, forKey: key as NSString)
        pthread_mutex_unlock(&lock)
    }
    
    public func downloadProgress(forKey key: String) -> Double {
        pthread_mutex_lock(&lock)
        let p = downloadProgressDic[key] ?? 0
        pthread_mutex_unlock(&lock)
        return p
    }
    
    public func setDownloadProgress(_ downloadProgress: Double, forKey key: String) {
        pthread_mutex_lock(&lock)
        downloadProgressDic[key] = downloadProgress
        pthread_mutex_unlock(&lock)
    }
}

/// Default behaivor of BBWebCache
public extension BBWebCache {
    var bb_webCacheOperation: BBWebCacheOperation {
        if let operation = objc_getAssociatedObject(self, &webCacheOperationKey) as? BBWebCacheOperation { return operation }
        let operation = BBWebCacheOperation()
        objc_setAssociatedObject(self, &webCacheOperationKey, operation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return operation
    }
    
    func bb_setImage(with resource: BBWebCacheResource,
                     placeholder: UIImage? = nil,
                     options: BBWebImageOptions = .none,
                     editor: BBWebImageEditor? = nil,
                     taskKey: String,
                     setImage: @escaping BBSetImage,
                     progress: BBImageDownloaderProgress? = nil,
                     completion: BBWebImageManagerCompletion? = nil) {
        let webCacheOperation = bb_webCacheOperation
        webCacheOperation.task(forKey: taskKey)?.cancel()
        webCacheOperation.setDownloadProgress(0 ,forKey: taskKey)
        if !options.contains(.ignorePlaceholder) {
            DispatchQueue.main.bb_safeSync { [weak self] in
                if self != nil { setImage(placeholder) }
            }
        }
        var currentProgress = progress
        var sentinel: Int32 = 0
        if options.contains(.progressiveDownload) {
            currentProgress = { [weak self] (data, expectedSize, image) in
                guard let self = self else { return }
                guard let partialData = data,
                    expectedSize > 0,
                    let partialImage = image else {
                        progress?(data, expectedSize, nil)
                        return
                }
                var displayImage = partialImage
                if let currentEditor = editor,
                    let currentImage = currentEditor.edit(partialImage) {
                    currentImage.bb_imageEditKey = currentEditor.key
                    currentImage.bb_imageFormat = partialData.bb_imageFormat
                    displayImage = currentImage
                } else if !options.contains(.ignoreImageDecoding),
                    let currentImage = BBWebImageManager.shared.imageCoder.decompressedImage(with: partialImage, data: partialData) {
                    displayImage = currentImage
                }
                let downloadProgress = min(1, Double(partialData.count) / Double(expectedSize))
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let webCacheOperation = self.bb_webCacheOperation
                    guard let task = webCacheOperation.task(forKey: taskKey),
                        task.sentinel == sentinel,
                        !task.isCancelled,
                        webCacheOperation.downloadProgress(forKey: taskKey) < downloadProgress else { return }
                    setImage(displayImage)
                    webCacheOperation.setDownloadProgress(downloadProgress, forKey: taskKey)
                }
                if let userProgress = progress {
                    let webCacheOperation = self.bb_webCacheOperation
                    if let task = webCacheOperation.task(forKey: taskKey),
                        task.sentinel == sentinel,
                        !task.isCancelled {
                        userProgress(partialData, expectedSize, displayImage)
                    }
                }
            }
        }
        let task = BBWebImageManager.shared.loadImage(with: resource, options: options, editor: editor, progress: currentProgress) { [weak self] (image: UIImage?, data: Data?, error: Error?, cacheType: BBImageCacheType) in
            guard let self = self else { return }
            if let currentImage = image { setImage(currentImage) }
            if error == nil { self.bb_webCacheOperation.setDownloadProgress(1, forKey: taskKey) }
            completion?(image, data, error, cacheType)
        }
        webCacheOperation.setTask(task, forKey: taskKey)
        sentinel = task.sentinel
    }
}
