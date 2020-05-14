//
//  ImageWebCacheable.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/14.
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
    

import Foundation

public typealias LonginusSetImageBlock = (UIImage?) -> Void

private var webCacheOperationKey: Void?

/// BBWebCache defines image loading, editing and setting behaivors
public protocol ImageWebCacheable: AnyObject {
    func setImage(with resource: ImageWebCacheResourceable,
                  placeholder: UIImage?,
                  options: ImageOptions,
                  editor: ImageTransformer?,
                  taskKey: String,
                  setImage: @escaping LonginusSetImageBlock,
                  progress: ImageDownloaderProgressBlock?,
                  completion: ImageManagerCompletionBlock?)
}

public extension ImageWebCacheable {
    var webCacheOperation: BBWebCacheOperation {
        if let operation = objc_getAssociatedObject(self, &webCacheOperationKey) as? BBWebCacheOperation { return operation }
        let operation = BBWebCacheOperation()
        setRetainedAssociatedObject(self, &webCacheOperationKey, operation)
        return operation
    }
    
    func setImage(with resource: ImageWebCacheResourceable,
                  placeholder: UIImage?,
                  options: ImageOptions,
                  editor: ImageTransformer?,
                  taskKey: String,
                  setImage: @escaping LonginusSetImageBlock,
                  progress: ImageDownloaderProgressBlock?,
                  completion: ImageManagerCompletionBlock?) {
        let webCacheOperation = self.webCacheOperation
        webCacheOperation.task(forKey: taskKey)?.cancel()
        webCacheOperation.setDownloadProgress(0 ,forKey: taskKey)
        if !options.contains(.ignorePlaceholder) {
            DispatchQueue.main.lg.safeSync { [weak self] in
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
                    var currentImage = currentEditor.edit(partialImage) {
                    currentImage.lg.lgImageEditKey = currentEditor.key
                    currentImage.lg.imageFormat = partialData.lg.imageFormat
                    displayImage = currentImage
                } else if !options.contains(.ignoreImageDecoding),
                    let currentImage = LonginusManager.shared.imageCoder.decompressedImage(with: partialImage, data: partialData) {
                    displayImage = currentImage
                }
                let downloadProgress = min(1, Double(partialData.count) / Double(expectedSize))
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let webCacheOperation = self.webCacheOperation
                    guard let task = webCacheOperation.task(forKey: taskKey),
                        task.sentinel == sentinel,
                        !task.isCancelled,
                        webCacheOperation.downloadProgress(forKey: taskKey) < downloadProgress else { return }
                    setImage(displayImage)
                    webCacheOperation.setDownloadProgress(downloadProgress, forKey: taskKey)
                }
                if let userProgress = progress {
                    let webCacheOperation = self.webCacheOperation
                    if let task = webCacheOperation.task(forKey: taskKey),
                        task.sentinel == sentinel,
                        !task.isCancelled {
                        userProgress(partialData, expectedSize, displayImage)
                    }
                }
            }
        }
        let task = LonginusManager.shared.loadImage(with: resource, options: options, transformer: editor, progress: currentProgress) { [weak self] (image: UIImage?, data: Data?, error: Error?, cacheType: ImageCacheType) in
            guard let self = self else { return }
            if let currentImage = image { setImage(currentImage) }
            if error == nil { self.webCacheOperation.setDownloadProgress(1, forKey: taskKey) }
            completion?(image, data, error, cacheType)
        }
        webCacheOperation.setTask(task, forKey: taskKey)
        sentinel = task.sentinel
    }
}


public class BBWebCacheOperation {
    private let weakTaskMap: NSMapTable<NSString, ImageLoadTask>
    private var downloadProgressDic: [String : Double]
    private var lock: Mutex
    
    public init() {
        weakTaskMap = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        downloadProgressDic = [:]
        lock = Mutex()
    }
    
    public func task(forKey key: String) -> ImageLoadTask? {
        lock.locked { [weak self] in
            return self?.weakTaskMap.object(forKey: key as NSString)
        }
    }
    
    public func setTask(_ task: ImageLoadTask, forKey key: String) {
        lock.locked { [weak self] in
            return self?.weakTaskMap.setObject(task, forKey: key as NSString)
        }
    }
    
    public func downloadProgress(forKey key: String) -> Double {
        lock.locked { [weak self] in
            return self?.downloadProgressDic[key] ?? 0
        }
    }
    
    public func setDownloadProgress(_ downloadProgress: Double, forKey key: String) {
        lock.locked { [weak self] in
            self?.downloadProgressDic[key] = downloadProgress
        }
    }
}
