//
//  BBAnimatedImage.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2/6/19.
//  Copyright © 2019 Kaibo Lu. All rights reserved.
//

import UIKit

private struct BBAnimatedImageFrame {
    fileprivate var image: UIImage? {
        didSet {
            if let currentImage = image {
                size = currentImage.size
            }
        }
    }
    fileprivate var size: CGSize?
    fileprivate var duration: TimeInterval
    
    fileprivate var bytes: Int64? { return image?.bb_bytes }
}

/// BBAnimatedImage manages animated image data
public class BBAnimatedImage: UIImage {
    /// Editor editing image frames
    public var bb_editor: BBWebImageEditor? {
        get {
            lock.wait()
            let e = editor
            lock.signal()
            return e
        }
        set {
            lock.wait()
            if newValue?.key != editor?.key {
                editor = newValue
                cachedFrameCount = 0
            }
            lock.signal()
        }
    }
    
    /// Number of image frames
    public var bb_frameCount: Int { return frameCount }
    
    /// Number of times to repeat the animation
    public var bb_loopCount: Int { return loopCount }
    
    /// Max cache size in bytes. Max cache size is auto updated by default.
    /// Setting this property with non-negative value disables auto update max cache size strategy.
    /// Setting this property with negative value enables auto update max cache size strategy.
    public var bb_maxCacheSize: Int64 {
        get {
            lock.wait()
            let m = maxCacheSize!
            lock.signal()
            return m
        }
        set {
            lock.wait()
            if newValue >= 0 {
                autoUpdateMaxCacheSize = false
                maxCacheSize = newValue
            } else {
                autoUpdateMaxCacheSize = true
                updateCacheSize()
            }
            lock.signal()
        }
    }
    
    /// Current cache size in bytes
    public var bb_currentCacheSize: Int64 {
        lock.wait()
        let s = currentCacheSize!
        lock.signal()
        return s
    }
    
    /// Original image data used when creating the image
    public var bb_originalImageData: Data { return decoder.imageData! }
    
    private var editor: BBWebImageEditor?
    private var frameCount: Int!
    private var loopCount: Int!
    private var maxCacheSize: Int64!
    private var currentCacheSize: Int64!
    private var autoUpdateMaxCacheSize: Bool!
    private var cachedFrameCount: Int!
    private var frames: [BBAnimatedImageFrame]!
    private var decoder: BBAnimatedImageCoder!
    private var views: NSHashTable<BBAnimatedImageView>!
    private var lock: DispatchSemaphore!
    private var sentinel: Int32!
    private var preloadTask: (() -> Void)?
    
    deinit {
        bb_cancelPreloadTask()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Creates animated image with data and decoder.
    /// If specify decoder to nil, this method tries to find a coder from BBWebImageManager shared instance.
    /// If no decoder found or decoder can not decode data, this method returns nil.
    ///
    /// - Parameters:
    ///   - data: image data
    ///   - aDecoder: animated image data decoder
    public convenience init?(bb_data data: Data, decoder aDecoder: BBAnimatedImageCoder? = nil) {
        var tempDecoder = aDecoder
        if tempDecoder == nil {
            if let manager = BBWebImageManager.shared.imageCoder as? BBImageCoderManager {
                for coder in manager.coders {
                    if let animatedCoder = coder as? BBAnimatedImageCoder,
                        animatedCoder.canDecode(data) {
                        tempDecoder = animatedCoder.copy() as? BBAnimatedImageCoder
                        break
                    }
                }
            }
        }
        guard let currentDecoder = tempDecoder, currentDecoder.canDecode(data) else { return nil }
        currentDecoder.imageData = data
        guard let firstFrame = currentDecoder.imageFrame(at: 0, decompress: true),
            let firstFrameSourceImage = firstFrame.cgImage,
            let currentFrameCount = currentDecoder.frameCount,
            currentFrameCount > 0 else { return nil }
        var imageFrames: [BBAnimatedImageFrame] = []
        for i in 0..<currentFrameCount {
            if let duration = currentDecoder.duration(at: i) {
                let image = (i == 0 ? firstFrame : nil)
                let size = currentDecoder.imageFrameSize(at: i)
                imageFrames.append(BBAnimatedImageFrame(image: image, size: size, duration: duration))
            } else {
                return nil
            }
        }
        self.init(cgImage: firstFrameSourceImage, scale: 1, orientation: firstFrame.imageOrientation)
        bb_imageFormat = data.bb_imageFormat
        frameCount = currentFrameCount
        loopCount = currentDecoder.loopCount ?? 0
        maxCacheSize = .max
        currentCacheSize = Int64(imageFrames.first!.bytes!)
        autoUpdateMaxCacheSize = true
        cachedFrameCount = 1
        frames = imageFrames
        decoder = currentDecoder
        views = NSHashTable(options: .weakMemory)
        lock = DispatchSemaphore(value: 1)
        sentinel = 0
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    /// Gets image frame at specified index
    ///
    /// - Parameters:
    ///   - index: frame index
    ///   - decodeIfNeeded: whether to decode or edit image if no cached image found
    /// - Returns: image frame, or nil if fail
    public func bb_imageFrame(at index: Int, decodeIfNeeded: Bool) -> UIImage? {
        if index >= frameCount { return nil }
        lock.wait()
        let cacheImage = frames[index].image
        let editor = self.editor
        lock.signal()
        return imageFrame(at: index,
                          cachedImage: cacheImage,
                          editor: editor,
                          decodeIfNeeded: decodeIfNeeded)
    }
    
    private func imageFrame(at index: Int,
                            cachedImage: UIImage?,
                            editor bbEditor: BBWebImageEditor?,
                            decodeIfNeeded: Bool) -> UIImage? {
        if let currentImage = cachedImage {
            if let editor = bbEditor {
                if currentImage.bb_imageEditKey == editor.key {
                    return currentImage
                } else if decodeIfNeeded {
                    if currentImage.bb_imageEditKey == nil {
                        let editedImage = editor.edit(currentImage)
                        editedImage?.bb_imageEditKey = editor.key
                        return editedImage
                    } else if let imageFrame = decoder.imageFrame(at: index, decompress: false) {
                        let editedImage = editor.edit(imageFrame)
                        editedImage?.bb_imageEditKey = editor.key
                        return editedImage
                    }
                }
            } else if currentImage.bb_imageEditKey == nil {
                return currentImage
            } else if decodeIfNeeded {
                return decoder.imageFrame(at: index, decompress: true)
            }
        }
        if !decodeIfNeeded { return nil }
        if let editor = bbEditor {
            if let imageFrame = decoder.imageFrame(at: index, decompress: false) {
                let editedImage = editor.edit(imageFrame)
                editedImage?.bb_imageEditKey = editor.key
                return editedImage
            }
        } else {
            return decoder.imageFrame(at: index, decompress: true)
        }
        return nil
    }
    
    /// Gets image frame duration at specified index
    ///
    /// - Parameter index: frame index
    /// - Returns: image frame duration, or nil if fail
    public func bb_duration(at index: Int) -> TimeInterval? {
        if index >= frameCount { return nil }
        lock.wait()
        let duration = frames[index].duration
        lock.signal()
        return duration
    }
    
    /// Updates max cache size if auto update strategy is used
    public func bb_updateCacheSizeIfNeeded() {
        lock.wait()
        defer { lock.signal() }
        if !autoUpdateMaxCacheSize { return }
        updateCacheSize()
    }
    
    private func updateCacheSize() {
        let total = Int64(Double(UIDevice.bb_totalMemory) * 0.2)
        let free = Int64(Double(UIDevice.bb_freeMemory) * 0.6)
        maxCacheSize = min(total, free)
    }
    
    /// Preload image frame asynchronously
    ///
    /// - Parameter startIndex: frame index to start preloading
    public func bb_preloadImageFrame(fromIndex startIndex: Int) {
        if startIndex >= frameCount { return }
        lock.wait()
        let shouldReturn = (preloadTask != nil || cachedFrameCount >= frameCount)
        lock.signal()
        if shouldReturn { return }
        let sentinel = self.sentinel
        let work: () -> Void = { [weak self] in
            guard let self = self, sentinel == self.sentinel else { return }
            self.lock.wait()
            let cleanCache = (self.currentCacheSize > self.maxCacheSize)
            self.lock.signal()
            if cleanCache {
                for i in 0..<self.frameCount {
                    let index = (startIndex + self.frameCount * 2 - i - 2) % self.frameCount // last second frame of start index
                    var shouldBreak = false
                    self.lock.wait()
                    if let oldImage = self.frames[index].image {
                        self.frames[index].image = nil
                        self.cachedFrameCount -= 1
                        self.currentCacheSize -= oldImage.bb_bytes
                        shouldBreak = (self.currentCacheSize <= self.maxCacheSize)
                    }
                    self.lock.signal()
                    if shouldBreak { break }
                }
                return
            }
            for i in 0..<self.frameCount {
                let index = (startIndex + i) % self.frameCount
                if let image = self.bb_imageFrame(at: index, decodeIfNeeded: true) {
                    if sentinel != self.sentinel { return }
                    var shouldBreak = false
                    self.lock.wait()
                    if let oldImage = self.frames[index].image {
                        if oldImage.bb_imageEditKey != image.bb_imageEditKey {
                            if self.currentCacheSize + image.bb_bytes - oldImage.bb_bytes <= self.maxCacheSize {
                                self.frames[index].image = image
                                self.cachedFrameCount += 1
                                self.currentCacheSize += image.bb_bytes - oldImage.bb_bytes
                            } else {
                                shouldBreak = true
                            }
                        }
                    } else if self.currentCacheSize + image.bb_bytes <= self.maxCacheSize {
                        self.frames[index].image = image
                        self.cachedFrameCount += 1
                        self.currentCacheSize += image.bb_bytes
                    } else {
                        shouldBreak = true
                    }
                    self.lock.signal()
                    if shouldBreak { break }
                }
            }
            self.lock.wait()
            if sentinel == self.sentinel { self.preloadTask = nil }
            self.lock.signal()
        }
        lock.wait()
        preloadTask = work
        BBDispatchQueuePool.default.async(work: work)
        lock.signal()
    }
    
    /// Preload all image frames synchronously
    public func bb_preloadAllImageFrames() {
        lock.wait()
        autoUpdateMaxCacheSize = false
        maxCacheSize = .max
        cachedFrameCount = 0
        currentCacheSize = 0
        for i in 0..<frames.count {
            if let image = imageFrame(at: i,
                                      cachedImage: frames[i].image,
                                      editor: editor,
                                      decodeIfNeeded: true) {
                frames[i].image = image
                cachedFrameCount += 1
                currentCacheSize += image.bb_bytes
            }
        }
        lock.signal()
    }
    
    /// The image is added to a given image view.
    /// Call this method when the image is set to an image view.
    ///
    /// - Parameter view: image view displaying the image
    public func bb_didAddToView(_ view: BBAnimatedImageView) {
        views.add(view)
    }
    
    /// The image is removed from a given image view.
    /// Call this method when the image is removed from an image view.
    ///
    /// - Parameter view: image view displaying the image
    public func bb_didRemoveFromView(_ view: BBAnimatedImageView) {
        views.remove(view)
        if views.count <= 0 {
            bb_cancelPreloadTask()
            bb_clearAsynchronously(completion: nil)
        }
    }
    
    /// Cancels asynchronous preload task
    public func bb_cancelPreloadTask() {
        lock.wait()
        if preloadTask != nil {
            OSAtomicIncrement32(&sentinel)
            preloadTask = nil
        }
        lock.signal()
    }
    
    /// Removes all image frames from cache asynchronously
    ///
    /// - Parameter completion: a closure called when clearing is finished
    public func bb_clearAsynchronously(completion: (() -> Void)?) {
        BBDispatchQueuePool.default.async { [weak self] in
            guard let self = self else { return }
            self.bb_clear()
            completion?()
        }
    }
    
    /// Removes all image frames from cache synchronously
    public func bb_clear() {
        lock.wait()
        for i in 0..<frames.count {
            frames[i].image = nil
        }
        cachedFrameCount = 0
        currentCacheSize = 0
        lock.signal()
    }
    
    @objc private func didReceiveMemoryWarning() {
        bb_cancelPreloadTask()
        bb_clearAsynchronously { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                self.bb_updateCacheSizeIfNeeded()
            }
        }
    }
    
    @objc private func didEnterBackground() {
        bb_cancelPreloadTask()
        bb_clear()
    }
    
    @objc private func didBecomeActive() {
        bb_updateCacheSizeIfNeeded()
    }
}
