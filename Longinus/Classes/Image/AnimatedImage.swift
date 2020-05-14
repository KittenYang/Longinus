//
//  AnimatedImage.swift
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

public class AnimatedImage: UIImage {
    private struct AnimatedImageFrame {
        fileprivate var image: UIImage? {
            didSet {
                if let currentImage = image {
                    size = currentImage.size
                }
            }
        }
        fileprivate var size: CGSize?
        fileprivate var duration: TimeInterval
        
        fileprivate var bytes: Int64? { return image?.lg.bytes }
    }
    
    /// Editor editing image frames
    public var lg_transformer: ImageTransformer? {
        get {
            lock.wait()
            let t = transformer
            lock.signal()
            return t
        }
        set {
            lock.wait()
            if newValue?.key != transformer?.key {
                transformer = newValue
                cachedFrameCount = 0
            }
            lock.signal()
        }
    }
    
    public var lg_originalImageData: Data { return decoder.imageData! }
    public var lg_frameCount: Int { return frameCount }
    public var lg_loopCount: Int { return loopCount }
    public var lg_maxCacheSize: Int64 {
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
    public var lg_currentCacheSize: Int64 {
        lock.wait()
        let s = currentCacheSize!
        lock.signal()
        return s
    }
    
    private var transformer: ImageTransformer?
    private(set) var frameCount: Int!
    private(set) var loopCount: Int!
    private(set) var maxCacheSize: Int64!
    private(set) var currentCacheSize: Int64!
    private(set) var autoUpdateMaxCacheSize: Bool!
    private(set) var cachedFrameCount: Int!
    private var frames: [AnimatedImageFrame]!
    private(set) var decoder: AnimatedImageCodeable!
    private(set) var views: NSHashTable<AnimatedImageView>!
    private(set) var lock: DispatchSemaphore!
    private(set) var sentinel: Int32!
    private(set) var preloadTask: (() -> Void)?
    
    
    deinit {
        lg_cancelPreloadTask()
        NotificationCenter.default.removeObserver(self)
    }
    
    public convenience init?(lg_data data: Data, decoder aDecoder: AnimatedImageCodeable? = nil) {
        var tempDecoder = aDecoder
        if tempDecoder == nil {
            if let manager = LonginusManager.shared.imageCoder as? ImageCoderManager {
                for coder in manager.coders {
                    if let animatedCoder = coder as? AnimatedImageCodeable,
                        animatedCoder.canDecode(data) {
                        tempDecoder = animatedCoder.copy() as? AnimatedImageCodeable
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
        var imageFrames: [AnimatedImageFrame] = []
        for i in 0..<currentFrameCount {
            if let duration = currentDecoder.duration(at: i) {
                let image = (i == 0 ? firstFrame : nil)
                let size = currentDecoder.imageFrameSize(at: i)
                imageFrames.append(AnimatedImageFrame(image: image, size: size, duration: duration))
            } else {
                return nil
            }
        }
        self.init(cgImage: firstFrameSourceImage, scale: 1, orientation: firstFrame.imageOrientation)
        var m_lg = self.lg
        m_lg.imageFormat = data.lg.imageFormat
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
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: .UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: .UIApplicationDidBecomeActive, object: nil)
    }
    
    public func lg_imageFrame(at index: Int, decodeIfNeeded: Bool) -> UIImage? {
        if index >= frameCount { return nil }
        lock.wait()
        let cacheImage = frames[index].image
        let transformer = self.transformer
        lock.signal()
        return imageFrame(at: index,
                          cachedImage: cacheImage,
                          transformer: transformer,
                          decodeIfNeeded: decodeIfNeeded)
    }
    
    public func lg_duration(at index: Int) -> TimeInterval? {
        if index >= frameCount { return nil }
        lock.wait()
        let duration = frames[index].duration
        lock.signal()
        return duration
    }
    
    public func lg_updateCacheSizeIfNeeded() {
        lock.wait()
        defer { lock.signal() }
        if !autoUpdateMaxCacheSize { return }
        updateCacheSize()
    }
    
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
                        self.currentCacheSize -= oldImage.lg.bytes
                        shouldBreak = (self.currentCacheSize <= self.maxCacheSize)
                    }
                    self.lock.signal()
                    if shouldBreak { break }
                }
                return
            }
            for i in 0..<self.frameCount {
                let index = (startIndex + i) % self.frameCount
                if let image = self.lg_imageFrame(at: index, decodeIfNeeded: true) {
                    if sentinel != self.sentinel { return }
                    var shouldBreak = false
                    self.lock.wait()
                    if let oldImage = self.frames[index].image {
                        if oldImage.lg.lgImageEditKey != image.lg.lgImageEditKey {
                            if self.currentCacheSize + image.lg.bytes - oldImage.lg.bytes <= self.maxCacheSize {
                                self.frames[index].image = image
                                self.cachedFrameCount += 1
                                self.currentCacheSize += image.lg.bytes - oldImage.lg.bytes
                            } else {
                                shouldBreak = true
                            }
                        }
                    } else if self.currentCacheSize + image.lg.bytes <= self.maxCacheSize {
                        self.frames[index].image = image
                        self.cachedFrameCount += 1
                        self.currentCacheSize += image.lg.bytes
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
        DispatchQueuePool.default.async(work: work)
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
                                      transformer: transformer,
                                      decodeIfNeeded: true) {
                frames[i].image = image
                cachedFrameCount += 1
                currentCacheSize += image.lg.bytes
            }
        }
        lock.signal()
    }
    
    public func lg_didAddToView(_ view: AnimatedImageView) {
        views.add(view)
    }
    
    public func lg_didRemoveFromView(_ view: AnimatedImageView) {
        views.remove(view)
        if views.count <= 0 {
            lg_cancelPreloadTask()
            lg_clearAsynchronously(completion: nil)
        }
    }
    
    /// Cancels asynchronous preload task
    public func lg_cancelPreloadTask() {
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
    public func lg_clearAsynchronously(completion: (() -> Void)?) {
        DispatchQueuePool.default.async { [weak self] in
            guard let self = self else { return }
            self.lg_clear()
            completion?()
        }
    }
    
    /// Removes all image frames from cache synchronously
    public func lg_clear() {
        lock.wait()
        for i in 0..<frames.count {
            frames[i].image = nil
        }
        cachedFrameCount = 0
        currentCacheSize = 0
        lock.signal()
    }
    
}

// MARK: Notifications
extension AnimatedImage {
    @objc private func didReceiveMemoryWarning() {
        lg_cancelPreloadTask()
        lg_clearAsynchronously { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                self.lg_updateCacheSizeIfNeeded()
            }
        }
    }
    
    @objc private func didEnterBackground() {
        lg_cancelPreloadTask()
        lg_clear()
    }
    
    @objc private func didBecomeActive() {
        lg_updateCacheSizeIfNeeded()
    }
}


extension AnimatedImage {
    private func imageFrame(at index: Int,
                            cachedImage: UIImage?,
                            transformer imageTransformer: ImageTransformer?,
                            decodeIfNeeded: Bool) -> UIImage? {
        if let currentImage = cachedImage {
            if let editor = transformer {
                if currentImage.lg.lgImageEditKey == editor.key {
                    return currentImage
                } else if decodeIfNeeded {
                    if currentImage.lg.lgImageEditKey == nil {
                        var editedImage = editor.edit(currentImage)
                        editedImage?.lg.lgImageEditKey = editor.key
                        return editedImage
                    } else if let imageFrame = decoder.imageFrame(at: index, decompress: false) {
                        var editedImage = editor.edit(imageFrame)
                        editedImage?.lg.lgImageEditKey = editor.key
                        return editedImage
                    }
                }
            } else if currentImage.lg.lgImageEditKey == nil {
                return currentImage
            } else if decodeIfNeeded {
                return decoder.imageFrame(at: index, decompress: true)
            }
        }
        if !decodeIfNeeded { return nil }
        if let editor = transformer {
            if let imageFrame = decoder.imageFrame(at: index, decompress: false) {
                var editedImage = editor.edit(imageFrame)
                editedImage?.lg.lgImageEditKey = editor.key
                return editedImage
            }
        } else {
            return decoder.imageFrame(at: index, decompress: true)
        }
        return nil
    }
    
    private func updateCacheSize() {
        let total = Int64(Double(LonginusExtension<UIDevice>.totalMemory) * 0.2)
        let free = Int64(Double(LonginusExtension<UIDevice>.freeMemory) * 0.6)
        maxCacheSize = min(total, free)
    }
}
