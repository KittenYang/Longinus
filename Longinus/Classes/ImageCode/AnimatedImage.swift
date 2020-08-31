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

/**
 LonginusExtension to AnimatedImage. You can access these variables or functions by `lg` property.
 */
public extension LonginusExtension where Base: AnimatedImage {
    /**
     A ImageTransformer to edit image frames
     */
    var transformer: ImageTransformer? {
        get {
            base.lock.lock()
            let t = base.transformer
            base.lock.unlock()
            return t
        }
        set {
            base.lock.lock()
            if newValue?.key != base.transformer?.key {
                base.transformer = newValue
                base.cachedFrameCount = 0
            }
            base.lock.unlock()
        }
    }
    
    /**
     The originalImageData of AnimatedImage
     */
    var originalImageData: Data? { return base.decoder.imageData }
    
    /**
     Current cache size in bytes
     */
    var currentCacheSize: Int64 {
        base.lock.lock()
        let size = base.currentCacheSize!
        base.lock.unlock()
        return size
    }
 
    /**
     Update max cache size in bytes to fit device freeMemory
     */
    func updateCacheSizeIfNeeded() {
        base.lock.lock()
        defer { base.lock.unlock() }
        if !base.autoUpdateMaxCacheSize { return }
        base.updateCacheSize()
    }
    
    /**
    Preload specific frame image to memory.
    */
    func preloadImageFrame(fromIndex startIndex: Int) {
        if startIndex >= base.frameCount ?? 0 { return }
        base.lock.lock()
        let shouldReturn = (base.preloadTask != nil || base.cachedFrameCount >= base.frameCount ?? 0)
        base.lock.unlock()
        if shouldReturn { return }
        let sentinel = base.sentinel
        let work: () -> Void = { [weak base] in
            guard let base = base, sentinel == base.sentinel, let frameCount = base.frameCount else { return }
            base.lock.lock()
            let cleanCache = (base.currentCacheSize > base.maxCacheSize)
            base.lock.unlock()
            if cleanCache {
                for i in 0..<frameCount {
                    let index = (startIndex + frameCount * 2 - i - 2) % frameCount // last second frame of start index
                    var shouldBreak = false
                    base.lock.lock()
                    if let oldImage = base.frames[index].image {
                        base.frames[index].image = nil
                        base.cachedFrameCount -= 1
                        base.currentCacheSize -= oldImage.cacheCost
                        shouldBreak = (base.currentCacheSize <= base.maxCacheSize)
                    }
                    base.lock.unlock()
                    if shouldBreak { break }
                }
                return
            }
            for i in 0..<frameCount {
                let index = (startIndex + i) % frameCount
                if let image = base.imageFrame(at: index, decompress: true) {
                    if sentinel != base.sentinel { return }
                    var shouldBreak = false
                    base.lock.lock()
                    if let oldImage = base.frames[index].image {
                        if oldImage.lg.lgImageEditKey != image.lg.lgImageEditKey {
                            if base.currentCacheSize + image.cacheCost - oldImage.cacheCost <= base.maxCacheSize {
                                base.frames[index].image = image
                                base.cachedFrameCount += 1
                                base.currentCacheSize += image.cacheCost - oldImage.cacheCost
                            } else {
                                shouldBreak = true
                            }
                        }
                    } else if base.currentCacheSize + image.cacheCost <= base.maxCacheSize {
                        base.frames[index].image = image
                        base.cachedFrameCount += 1
                        base.currentCacheSize += image.cacheCost
                    } else {
                        shouldBreak = true
                    }
                    base.lock.unlock()
                    if shouldBreak { break }
                }
            }
            base.lock.lock()
            if sentinel == base.sentinel { base.preloadTask = nil }
            base.lock.unlock()
        }
        base.lock.lock()
        base.preloadTask = work
        DispatchQueuePool.default.async(work: work)
        base.lock.unlock()
    }
    
    /**
    Preload all frame image to memory.
    
    @discussion Call this methods will block the calling thread to decode
    all animation frame image to memory.
    If the image is shared by lots of image views (such as emoticon), preload all
    frames will reduce the CPU cost.
    */
    func preloadAllImageFrames() {
        base.lock.lock()
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
                base.currentCacheSize += image.cacheCost
            }
        }
        base.lock.unlock()
    }
    
    /**
     Weak refrence view to `views` NSHashTable
     */
    func didAddToView(_ view: AnimatedImageView) {
        base.views.add(view)
    }
    
    /**
     Remove view from `views` NSHashTable. If `views` is empty, cancel the preload work and clear cached buffer
     */
    func didRemoveFromView(_ view: AnimatedImageView) {
        base.views.remove(view)
        if base.views.count <= 0 {
            cancelPreloadTask()
            clearAsynchronously(completion: nil)
        }
    }
    
    /**
     Cancel preload task
     */
    func cancelPreloadTask() {
        base.lock.lock()
        if base.preloadTask != nil {
            OSAtomicIncrement32(&base.sentinel)
            base.preloadTask = nil
        }
        base.lock.unlock()
    }
    
    /**
     Removes all image frames from cache asynchronously
     
     - Parameters:
        - completion: A closure called when clearing is finished
     */
    func clearAsynchronously(completion: (() -> Void)?) {
        DispatchQueuePool.default.async { [weak base] in
            guard let base = base else { return }
            base.lg.clear()
            completion?()
        }
    }
    
    /**
     Removes all image frames from cache synchronously
     */
    func clear() {
        base.lock.lock()
        for i in 0..<base.frames.count {
            base.frames[i].image = nil
        }
        base.cachedFrameCount = 0
        base.currentCacheSize = 0
        base.lock.unlock()
    }
    
}

public class AnimatedImage: UIImage, AnimatedImageCodeable {
    
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
        
        fileprivate var bytes: Int64? { return image?.cacheCost }
    }

    fileprivate var transformer: ImageTransformer?
    fileprivate(set) var maxCacheSize: Int64!
    fileprivate(set) var currentCacheSize: Int64!
    fileprivate(set) var autoUpdateMaxCacheSize: Bool!
    fileprivate(set) var cachedFrameCount: Int!
    fileprivate var frames: [AnimatedImageFrame]!
    fileprivate(set) var decoder: (ImageCodeable & AnimatedImageCodeable)!
    fileprivate(set) var views: NSHashTable<AnimatedImageView>!
    fileprivate(set) var lock: DispatchSemaphore!
    fileprivate(set) var sentinel: Int32!
    fileprivate(set) var preloadTask: (() -> Void)?
    
    //MARK: AnimatedImageCodeable
    public var imageData: Data? {
        set {
            decoder?.imageData = newValue
            _bytePerFrame = decoder?.bytesPerFrame
        }
        get {
            return decoder.imageData
        }
    }
    
    public var frameCount: Int?
    public var loopCount: Int?
    
    private var _bytePerFrame: Int64?
    public var bytesPerFrame: Int64? {
        return _bytePerFrame
    }
    
    public func imageFrame(at index: Int, decompress: Bool) -> UIImage? {
        if index >= frameCount ?? 0 { return nil }
        lock.lock()
        let cacheImage = frames[index].image
        lock.unlock()
        return imageFrame(at: index,
                          cachedImage: cacheImage,
                          transformer: transformer,
                          decodeIfNeeded: decompress)
    }
    
       
    public func imageFrameSize(at index: Int) -> CGSize? {
        if index >= frameCount ?? 0 { return nil }
        lock.lock()
        let size = frames[index].size
        lock.unlock()
        return size
    }
    
    public func duration(at index: Int) -> TimeInterval? {
        if index >= frameCount ?? 0 { return nil }
        lock.lock()
        let duration = frames[index].duration
        lock.unlock()
        return duration
    }
    
    deinit {
        lg.cancelPreloadTask()
        NotificationCenter.default.removeObserver(self)
    }
    
    public convenience init?(lg_data data: Data, decoder aDecoder: (ImageCodeable & AnimatedImageCodeable)) {
        var currentDecoder = aDecoder
        guard currentDecoder.canDecode(data) else { return nil }
        currentDecoder.imageData = data
        let firstFrameBytes = currentDecoder.bytesPerFrame
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
        _bytePerFrame = firstFrameBytes
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
