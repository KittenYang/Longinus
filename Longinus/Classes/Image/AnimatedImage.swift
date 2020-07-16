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

extension LonginusExtension where Base: AnimatedImage {
    /// ImageTransformer editing image frames
    public var transformer: ImageTransformer? {
        get {
            base.lock.wait()
            let t = base.transformer
            base.lock.signal()
            return t
        }
        set {
            base.lock.wait()
            if newValue?.key != base.transformer?.key {
                base.transformer = newValue
                base.cachedFrameCount = 0
            }
            base.lock.signal()
        }
    }
    
    
    public var originalImageData: Data { return base.decoder.imageData! }
    public var frameCount: Int { return base.frameCount }
    public var loopCount: Int { return base.loopCount }
    public var maxCacheSize: Int64 {
        get {
            base.lock.wait()
            let m = base.maxCacheSize!
            base.lock.signal()
            return m
        }
        set {
            base.lock.wait()
            if newValue >= 0 {
                base.autoUpdateMaxCacheSize = false
                base.maxCacheSize = newValue
            } else {
                base.autoUpdateMaxCacheSize = true
                base.updateCacheSize()
            }
            base.lock.signal()
        }
    }
    
    
    /// Current cache size in bytes
    public var currentCacheSize: Int64 {
        base.lock.wait()
        let s = base.currentCacheSize!
        base.lock.signal()
        return s
    }
    
    public func imageFrame(at index: Int, decodeIfNeeded: Bool) -> UIImage? {
        if index >= frameCount { return nil }
        base.lock.wait()
        let cacheImage = base.frames[index].image
        let transformer = base.transformer
        base.lock.signal()
        return base.imageFrame(at: index,
                          cachedImage: cacheImage,
                          transformer: transformer,
                          decodeIfNeeded: decodeIfNeeded)
    }
    
    public func duration(at index: Int) -> TimeInterval? {
        if index >= frameCount { return nil }
        base.lock.wait()
        let duration = base.frames[index].duration
        base.lock.signal()
        return duration
    }
 
    public func updateCacheSizeIfNeeded() {
        base.lock.wait()
        defer { base.lock.signal() }
        if !base.autoUpdateMaxCacheSize { return }
        base.updateCacheSize()
    }
    
    public func preloadImageFrame(fromIndex startIndex: Int) {
        if startIndex >= base.frameCount { return }
        base.lock.wait()
        let shouldReturn = (base.preloadTask != nil || base.cachedFrameCount >= frameCount)
        base.lock.signal()
        if shouldReturn { return }
        let sentinel = base.sentinel
        let work: () -> Void = { [weak base] in
            guard let base = base, sentinel == base.sentinel else { return }
            base.lock.wait()
            let cleanCache = (base.currentCacheSize > base.maxCacheSize)
            base.lock.signal()
            if cleanCache {
                for i in 0..<base.frameCount {
                    let index = (startIndex + base.frameCount * 2 - i - 2) % base.frameCount // last second frame of start index
                    var shouldBreak = false
                    base.lock.wait()
                    if let oldImage = base.frames[index].image {
                        base.frames[index].image = nil
                        base.cachedFrameCount -= 1
                        base.currentCacheSize -= oldImage.lg.bytes
                        shouldBreak = (base.currentCacheSize <= base.maxCacheSize)
                    }
                    base.lock.signal()
                    if shouldBreak { break }
                }
                return
            }
            for i in 0..<base.frameCount {
                let index = (startIndex + i) % base.frameCount
                if let image = base.lg.imageFrame(at: index, decodeIfNeeded: true) {
                    if sentinel != base.sentinel { return }
                    var shouldBreak = false
                    base.lock.wait()
                    if let oldImage = base.frames[index].image {
                        if oldImage.lg.lgImageEditKey != image.lg.lgImageEditKey {
                            if base.currentCacheSize + image.lg.bytes - oldImage.lg.bytes <= base.maxCacheSize {
                                base.frames[index].image = image
                                base.cachedFrameCount += 1
                                base.currentCacheSize += image.lg.bytes - oldImage.lg.bytes
                            } else {
                                shouldBreak = true
                            }
                        }
                    } else if base.currentCacheSize + image.lg.bytes <= base.maxCacheSize {
                        base.frames[index].image = image
                        base.cachedFrameCount += 1
                        base.currentCacheSize += image.lg.bytes
                    } else {
                        shouldBreak = true
                    }
                    base.lock.signal()
                    if shouldBreak { break }
                }
            }
            base.lock.wait()
            if sentinel == base.sentinel { base.preloadTask = nil }
            base.lock.signal()
        }
        base.lock.wait()
        base.preloadTask = work
        DispatchQueuePool.default.async(work: work)
        base.lock.signal()
    }
    
    /// Preload all image frames synchronously
    public func preloadAllImageFrames() {
        base.lock.wait()
        base.autoUpdateMaxCacheSize = false
        base.maxCacheSize = .max
        base.cachedFrameCount = 0
        base.currentCacheSize = 0
        for i in 0..<base.frames.count {
            if let image = base.imageFrame(at: i,
                                      cachedImage: base.frames[i].image,
                                      transformer: base.transformer,
                                      decodeIfNeeded: true) {
                base.frames[i].image = image
                base.cachedFrameCount += 1
                base.currentCacheSize += image.lg.bytes
            }
        }
        base.lock.signal()
    }
    
    public func didAddToView(_ view: AnimatedImageView) {
        base.views.add(view)
    }
    
    public func didRemoveFromView(_ view: AnimatedImageView) {
        base.views.remove(view)
        if base.views.count <= 0 {
            cancelPreloadTask()
            clearAsynchronously(completion: nil)
        }
    }
    
    /// Cancels asynchronous preload task
    public func cancelPreloadTask() {
        base.lock.wait()
        if base.preloadTask != nil {
            OSAtomicIncrement32(&base.sentinel)
            base.preloadTask = nil
        }
        base.lock.signal()
    }
    
    /// Removes all image frames from cache asynchronously
    ///
    /// - Parameter completion: a closure called when clearing is finished
    public func clearAsynchronously(completion: (() -> Void)?) {
        DispatchQueuePool.default.async { [weak base] in
            guard let base = base else { return }
            base.lg.clear()
            completion?()
        }
    }
    
    /// Removes all image frames from cache synchronously
    public func clear() {
        base.lock.wait()
        for i in 0..<base.frames.count {
            base.frames[i].image = nil
        }
        base.cachedFrameCount = 0
        base.currentCacheSize = 0
        base.lock.signal()
    }
    
}

public class AnimatedImage: UIImage {
    fileprivate struct AnimatedImageFrame {
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

    fileprivate var transformer: ImageTransformer?
    fileprivate(set) var frameCount: Int!
    fileprivate(set) var loopCount: Int!
    fileprivate(set) var maxCacheSize: Int64!
    fileprivate(set) var currentCacheSize: Int64!
    fileprivate(set) var autoUpdateMaxCacheSize: Bool!
    fileprivate(set) var cachedFrameCount: Int!
    fileprivate var frames: [AnimatedImageFrame]!
    fileprivate(set) var decoder: AnimatedImageCodeable!
    fileprivate(set) var views: NSHashTable<AnimatedImageView>!
    fileprivate(set) var lock: DispatchSemaphore!
    fileprivate(set) var sentinel: Int32!
    fileprivate(set) var preloadTask: (() -> Void)?
    
    deinit {
        lg.cancelPreloadTask()
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
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    
}

// MARK: Notifications
extension AnimatedImage {
    @objc private func didReceiveMemoryWarning() {
        lg.cancelPreloadTask()
        lg.clearAsynchronously { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                self.lg.updateCacheSizeIfNeeded()
            }
        }
    }
    
    @objc private func didEnterBackground() {
        lg.cancelPreloadTask()
        lg.clear()
    }
    
    @objc private func didBecomeActive() {
        lg.updateCacheSizeIfNeeded()
    }
}


extension AnimatedImage {
    fileprivate func imageFrame(at index: Int,
                            cachedImage: UIImage?,
                            transformer imageTransformer: ImageTransformer?,
                            decodeIfNeeded: Bool) -> UIImage? {
        if let currentImage = cachedImage {
            if let transformer = transformer {
                if currentImage.lg.lgImageEditKey == transformer.key {
                    return currentImage
                } else if decodeIfNeeded {
                    if currentImage.lg.lgImageEditKey == nil {
                        var editedImage = transformer.transform(currentImage)
                        editedImage?.lg.lgImageEditKey = transformer.key
                        return editedImage
                    } else if let imageFrame = decoder.imageFrame(at: index, decompress: false) {
                        var editedImage = transformer.transform(imageFrame)
                        editedImage?.lg.lgImageEditKey = transformer.key
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
        if let transformer = transformer {
            if let imageFrame = decoder.imageFrame(at: index, decompress: false) {
                var editedImage = transformer.transform(imageFrame)
                editedImage?.lg.lgImageEditKey = transformer.key
                return editedImage
            }
        } else {
            return decoder.imageFrame(at: index, decompress: true)
        }
        return nil
    }
    
    fileprivate func updateCacheSize() {
        let total = Int64(Double(LonginusExtension<UIDevice>.totalMemory) * 0.2)
        let free = Int64(Double(LonginusExtension<UIDevice>.freeMemory) * 0.6)
        maxCacheSize = min(total, free)
    }
}
