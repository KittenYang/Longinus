//
//  AnimatedImageView.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/7/25.
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

public enum AnimatedImageViewType {
    case none
    case image
    case hilightedImage
    case animationImages
    case hilightedAnimationImages
}

open class AnimatedImageView: UIImageView {

    /**
     If the image has more than one frame, set this value to `YES` will automatically
     play/stop the animation when the view become visible/invisible.
     
     The default value is `YES`.
     */
    public var isAutoPlayAnimatedImage: Bool = true
    
    /**
     Index of the currently displayed frame (index from 0).
     
     Set a new value to this property will cause to display the new frame immediately.
     If the new value is invalid, this method has no effect.
     
     You can add an observer to this property to observe the playing status.
     */
    public var currentAnimatedImageIndex: Int = 0
    
    /**
     The animation timer's runloop mode, default is `NSDefaultRunLoopMode` which is not trigger animation during
     UIScrollView scrolling for better performance.
     
     Set this property to `NSRunLoopCommonModes` will make the animation play during
     UIScrollView scrolling.
     */
    public var runLoopMode: RunLoop.Mode = RunLoop.Mode.default {
        didSet {
            if runLoopMode == oldValue { return }
            if let oldLink = timer {
                // If remove old run loop mode and add new run loop mode, the animation will pause a while in iOS 8.
                // So create a new display link here.
                let isPaused = oldLink.isPaused
                oldLink.invalidate()
                let link = CADisplayLink(target: LonginusWeakProxy(target: self), selector: #selector(step(_:)))
                link.isPaused = isPaused
                link.add(to: RunLoop.main, forMode: runLoopMode)
                timer = link
            }
        }
    }
    
    /**
     Whether the image view is playing animation currently.
     
     You can add an observer to this property to observe the playing status.
     */
    public private(set) var currentIsPlayingAnimation: Bool = false
    
        
    /**
     Overrides Properties
     */
    override open var isAnimating: Bool {
        return currentIsPlayingAnimation
    }
    
    override open var image: UIImage? {
        set {
            setImage(image: newValue, with: .image)
        }
        get {
            return super.image
        }
    }
    
    override open var highlightedImage: UIImage? {
        set {
            setImage(image: newValue, with: .hilightedImage)
        }
        get {
            return super.highlightedImage
        }
    }
    
    override open var animationImages: [UIImage]? {
        set {
            setImage(image: newValue, with: .animationImages)
        }
        get {
            return super.animationImages
        }
    }
    
    override open var highlightedAnimationImages: [UIImage]? {
        set {
            setImage(image: newValue, with: .hilightedAnimationImages)
        }
        get {
            return super.highlightedAnimationImages
        }
    }
    
    // MARK: - Initialize methods
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    override public init(image: UIImage?) {
        super.init(frame: CGRect.zero)
        if image != nil {
            self.frame = CGRect(x: 0.0, y: 0.0, width: image!.size.width, height: image!.size.height)
        }
        self.image = image
    }
    
    override public init(image: UIImage?, highlightedImage: UIImage?) {
        super.init(frame: CGRect.zero)
        if image != nil {
            self.frame = CGRect(x: 0.0, y: 0.0, width: image!.size.width, height: image!.size.height)
        } else if (highlightedImage != nil) {
            self.frame = CGRect(x: 0.0,
                                y: 0.0,
                                width: highlightedImage!.size.width,
                                height: highlightedImage!.size.height)
        }
        self.image = image
        self.highlightedImage = highlightedImage
    }
    
    // MARK: - System decoder/encode methods
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        if let tempMode = aDecoder.decodeObject(forKey: "runLoopMode") as? RunLoop.Mode {
            runLoopMode = tempMode
        } else {
            runLoopMode = RunLoop.Mode.common
        }
        // decode bool 默认值为false，所以需要判断处理
        if aDecoder.containsValue(forKey: "isAutoPlayAnimatedImage") {
            isAutoPlayAnimatedImage = aDecoder.decodeBool(forKey: "isAutoPlayAnimatedImage")
        } else {
            isAutoPlayAnimatedImage = true
        }
        
        if let image = aDecoder.decodeObject(forKey: "lg_image") as? UIImage {
            self.image = image
            setImage(image: image, with: .image)
        }
        if let highlightedImage = aDecoder.decodeObject(forKey: "lg_highlightedImage") as? UIImage {
            self.highlightedImage = highlightedImage
            setImage(image: highlightedImage, with: .hilightedImage)
        }
        
    }
    
    override open func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(runLoopMode, forKey: "runLoopMode")
        aCoder.encode(isAutoPlayAnimatedImage, forKey: "isAutoPlayAnimatedImage")

        var ani: Bool = false, multi: Bool = false
        
        ani = self.image is AnimatedImageCodeable
        if ani {
            if let tempImage = self.image as? AnimatedImage, tempImage.frameCount ?? 0 > 1 {
                multi = true
            }
        }
        if multi { aCoder.encode(self.image, forKey: "lg_image") }
        
        ani = self.highlightedImage is AnimatedImageCodeable
        if ani {
            if let tempImage = self.highlightedImage as? AnimatedImage, tempImage.frameCount ?? 0 > 1 {
                multi = true
            }
        }
        if multi { aCoder.encode(self.image, forKey: "lg_highlightedImage") }
    }
    
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        didMoved()
    }
    
    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        didMoved()
    }
    
    override open func stopAnimating() {
        super.stopAnimating()
        requestQueue.cancelAllOperations()
        timer?.isPaused = true
        self.currentIsPlayingAnimation = false
    }
    
    override open func startAnimating() {
        let type: AnimatedImageViewType = currentImageType()
        if type == .animationImages || type == .hilightedAnimationImages {
            if let images = image(for: type) as? [UIImage] {
                if images.count > 0 {
                    super.startAnimating()
                    self.currentIsPlayingAnimation = true
                }
            }
        } else {
            if currentAnimatedImage != nil && timer?.isPaused == true {
                currentLoop = 0
                isLoopEnd = false
                timer?.isPaused = false
                self.currentIsPlayingAnimation = true
            }
        }
    }
    
    override open func display(_ layer: CALayer) {
        if currentFrame != nil {
            layer.contents = currentFrame?.cgImage
        }
    }
    
    /**
     The max size (in bytes) for inner frame buffer size, default is 0 (dynamically).
     
     When the device has enough free memory, this view will request and decode some or
     all future frame image into an inner buffer. If this property's value is 0, then
     the max buffer size will be dynamically adjusted based on the current state of
     the device free memory. Otherwise, the buffer size will be limited by this value.
     
     When receive memory warning or app enter background, the buffer will be released
     immediately, and may grow back at the right time.
     */
    private var maxBufferSize: Int = 0
    
    // MARK: -  fileprivate properties
    fileprivate var currentAnimatedImage: (UIImage & AnimatedImageCodeable)?

    fileprivate var lock: DispatchSemaphore = DispatchSemaphore(value: 1)
    fileprivate lazy var requestQueue: OperationQueue =  {
        return OperationQueue()
    }()
    fileprivate var timer: CADisplayLink?
    fileprivate var time: TimeInterval = 0
    
    fileprivate var currentFrame: UIImage?
    fileprivate var totalFrameCount: Int = 1
    
    fileprivate var isLoopEnd: Bool = false
    fileprivate var currentLoop: Int = 0
    fileprivate var totalLoop: Int = 0
    
    fileprivate var buffer: [Int: UIImage] = [Int: UIImage]()
    fileprivate var isBufferMiss: Bool = false // whether cache hitted
    fileprivate var incrBufferCount: Int = 0 // current buffer count
    fileprivate var maxBufferCount: Int = 0
    fileprivate var currentContentsRect: CGRect = CGRect.zero
    fileprivate var isCurrentImageHasContentsRect: Bool = false
    
    // MARK: - deinit
    deinit {
        requestQueue.cancelAllOperations()
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    // MARK: - Public
    public func currentImageType() -> AnimatedImageViewType {
        var result: AnimatedImageViewType = .none
        if self.isHighlighted {
            if highlightedAnimationImages != nil && highlightedAnimationImages?.count != 0 {
                result = .hilightedAnimationImages
            } else if self.highlightedImage != nil {
                result = .hilightedImage
            }
        }
        
        if result == .none {
            if animationImages != nil && animationImages?.count != 0 {
                result = .animationImages
            } else if self.image != nil {
                result = .image
            }
        }
        
        return result
    }
    
    public func setCurrentAnimatedImageIndex(_ index: Int) {
        if currentAnimatedImage == nil {
            return
        }
        if index >= currentAnimatedImage!.frameCount ?? 0 {
            return
        }
        if index == currentAnimatedImageIndex {
            return
        }
        
        func featureFunction() {
            lock.lock()
            requestQueue.cancelAllOperations()
            self.buffer.removeAll()
            currentFrame = currentAnimatedImage?.imageFrame(at: index, decompress: true)
            if isCurrentImageHasContentsRect {
                if let rect = currentAnimatedImage?.contentsRect(at: index) {
                    currentContentsRect = rect
                }
            }
            time = 0
            isLoopEnd = false
            isBufferMiss = false
            layer.setNeedsDisplay()
            lock.unlock()
        }
        
        if Thread.current.isMainThread {
            featureFunction()
        } else {
            DispatchQueue.main.lg.safeAsync {
                featureFunction()
            }
        }
    }
    
}

//MARK: - Helper
extension AnimatedImageView {
    
    fileprivate func calcMaxBufferCount() {
        guard var bytesCount = currentAnimatedImage?.bytesPerFrame else { return }
        if bytesCount == 0 { bytesCount = 1_024 }
        
        let total = LonginusExtension<UIDevice>.totalMemory
        let free = LonginusExtension<UIDevice>.freeMemory
        var maxCount = min(Double(total) * 0.2, Double(free) * 0.6)
        maxCount = max(maxCount, 10 * 1_024 * 1_024) // 10MB
        if maxBufferSize != 0 {
            maxCount = maxCount > Double(maxBufferSize) ? Double(maxBufferSize) : maxCount
        }
        var tempCount = maxCount / Double(bytesCount)
        if tempCount < 1 {
            tempCount = 1
        } else if tempCount > 512 {
            tempCount = 512
        }
        maxBufferCount = Int(tempCount)
    }
    
    fileprivate func setImage(image: Any?, with type: AnimatedImageViewType) {
        self.stopAnimating()
        if timer != nil {
            resetAnimated()
        }
        currentFrame = nil
        switch type {
        case .none:
            break
        case .image:
            super.image = image as? UIImage
            break
        case .animationImages:
            super.animationImages = image as? [UIImage]
            break
        case .hilightedImage:
            super.highlightedImage = image as? UIImage
            break
        case .hilightedAnimationImages:
            super.highlightedAnimationImages = image as? [UIImage]
            break
        }
        imageChanged()
    }
    
    fileprivate func imageChanged() {
        let newType = currentImageType()
        let newVisibleImage = image(for: newType)
        var newImageFrameCount:Int = 0
        var hasContentsRect: Bool = false
        if let tempImg = newVisibleImage as? AnimatedImageCodeable {
            newImageFrameCount = tempImg.frameCount ?? 0
            if newImageFrameCount > 1 {
                let firstFrameRect = tempImg.contentsRect(at: 0)
                hasContentsRect = firstFrameRect != nil && firstFrameRect != CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            }
        }
        
        if !hasContentsRect && isCurrentImageHasContentsRect  {
            if self.layer.contentsRect != CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0) {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.layer.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
                CATransaction.commit()
            }
        }
        isCurrentImageHasContentsRect = hasContentsRect
        
        if hasContentsRect {
            if let rect = (newVisibleImage as? AnimatedImageCodeable)?.contentsRect(at: 0) {
                setContentsRect(rect, for: newVisibleImage as? UIImage)
            }
        }
        
        if newImageFrameCount > 1 {
            self.resetAnimated()
            currentAnimatedImage = newVisibleImage as? UIImage & AnimatedImageCodeable
            currentFrame = newVisibleImage as? UIImage
            totalLoop = currentAnimatedImage?.loopCount ?? 0
            totalFrameCount = currentAnimatedImage?.frameCount ?? 1
            calcMaxBufferCount()
        }
        
        setNeedsDisplay()
        didMoved()
    }
    
    fileprivate func resetAnimated() {
        if timer == nil {
            lock = DispatchSemaphore(value: 1)
            buffer.removeAll()
            requestQueue = OperationQueue()
            requestQueue.maxConcurrentOperationCount = 1
            timer = CADisplayLink(target: LonginusWeakProxy(target: self), selector: #selector(step(_:)))
            timer?.add(to: RunLoop.main, forMode: runLoopMode)
            timer?.isPaused = true
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didReceiveMemoryWarning(_:)),
                                                   name: UIApplication.didReceiveMemoryWarningNotification,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didEnterBackground(_:)),
                                                   name: UIApplication.didEnterBackgroundNotification,
                                                   object: nil)
        }
        requestQueue.cancelAllOperations()
        
        lock.lock()
        if !buffer.isEmpty {
            let holder = buffer
            buffer = [:]
            DispatchQueue.global(qos: .background).async {
                // Capture the dictionary to global queue,
                // release these images in background to avoid blocking UI thread.
                _ = holder.description
            }
        }
        lock.unlock()
        timer?.isPaused = true
        time = 0
        
        if currentAnimatedImageIndex != 0 {
            self.willChangeValue(forKey: "currentAnimatedImageIndex")
            self.currentAnimatedImageIndex = 0
            self.didChangeValue(forKey: "currentAnimatedImageIndex")
        }
        
        currentAnimatedImage = nil
        currentFrame = nil
        currentLoop = 0
        totalLoop = 0
        totalFrameCount = 1
        isLoopEnd = false
        isBufferMiss = false
        incrBufferCount = 0
    }
    
    fileprivate func image(for type: AnimatedImageViewType) -> Any? {
        var result: Any? = nil
        switch type {
        case .none:
            result = nil
            break
        case .image:
            result = self.image
            break
        case .animationImages:
            result = self.animationImages
            break
        case .hilightedImage:
            result = self.highlightedImage
            break
        case .hilightedAnimationImages:
            result = self.highlightedAnimationImages
            break
        }
        return result
    }
    
    fileprivate func didMoved() {
        if isAutoPlayAnimatedImage {
            if self.superview != nil && self.window != nil {
                self.startAnimating()
            } else {
                self.stopAnimating()
            }
        }
    }
    
    fileprivate func setContentsRect(_ rect: CGRect, for image: UIImage?) {
        var layerRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        if image != nil {
            let imageSize = image!.size
            if imageSize.width > 0.01 && imageSize.height > 0.01 {
                layerRect.origin.x = rect.origin.x / imageSize.width
                layerRect.origin.y = rect.origin.y / imageSize.height
                layerRect.size.width = rect.size.width / imageSize.width
                layerRect.size.height = rect.size.height / imageSize.height
                layerRect = layerRect.intersection(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
                if layerRect.isNull || layerRect.isEmpty {
                    layerRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
                }
            }
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.layer.contentsRect = layerRect
        CATransaction.commit()
    }
    
}

// MARK: - selector
extension AnimatedImageView {
        
    @objc func step(_ timer: CADisplayLink) {
        guard let image = self.currentAnimatedImage else {
            return
        }
        if isLoopEnd { // view will keep in last frame
            stopAnimating()
            return
        }
                
        var nextIndex = (currentAnimatedImageIndex + 1) % totalFrameCount
        var delay: TimeInterval = 0
        if !isBufferMiss { // 上次命中缓存
            time += timer.duration
            delay = image.duration(at: currentAnimatedImageIndex) ?? 0
            if time < delay { return } // 当前这帧还没播放完
            time -= delay
            if nextIndex == 0 {
                currentLoop += 1
                if currentLoop >= totalLoop && totalLoop != 0 {
                    isLoopEnd = true
                    stopAnimating()
                    layer.setNeedsDisplay() // let system call `displayLayer:` before runloop sleep
                    return // stop at last frame
                }
            }
            delay = image.duration(at: nextIndex) ?? 0
            if time > delay  { time = delay } // do not jump over frame
        }
        
        var buffer = self.buffer
        var bufferedImage: UIImage? = nil
        var bufferIsFull = false
        
        lock.lock()
        bufferedImage = nextIndex < buffer.count ? buffer[nextIndex] : nil
        if bufferedImage != nil {
            if incrBufferCount < totalFrameCount {
                buffer.removeValue(forKey: nextIndex)
            }
            willChangeValue(forKey: "currentAnimatedImageIndex")
            currentAnimatedImageIndex = nextIndex
            didChangeValue(forKey: "currentAnimatedImageIndex")
            currentFrame = bufferedImage
            if isCurrentImageHasContentsRect {
                if let nextImageRect = image.contentsRect(at: nextIndex) {
                    currentContentsRect = nextImageRect
                }
                setContentsRect(currentContentsRect, for: currentFrame)
            }
            nextIndex = (currentAnimatedImageIndex + 1) % totalFrameCount
            isBufferMiss = false
            if buffer.count == totalFrameCount {
                bufferIsFull = true
            }
        } else {
            isBufferMiss = true
        }
        lock.unlock()
        
        if !isBufferMiss {
            layer.setNeedsDisplay() // let system call 'displayLayer:' before runloop sleep
        }
        
        if !bufferIsFull && requestQueue.operationCount == 0 {
            let operation = AnimatedImageFetchOperation()
            operation.imageView = self
            operation.nextIndex = nextIndex
            operation.currentImage = image
            requestQueue.addOperation(operation)
        }
    }
    
    @objc func didReceiveMemoryWarning(_ noti: Notification) {
        requestQueue.cancelAllOperations()
        requestQueue.addOperation { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.incrBufferCount = -60 - (Int)(arc4random() % 120) // about 1~3 seconds to grow back..
            let next = (weakSelf.currentAnimatedImageIndex + 1) % weakSelf.totalFrameCount
            weakSelf.lock.lock()
            let keys = weakSelf.buffer.keys
            for key in keys {
                if key != next { // keep the next frame for smoothly animation
                    _ = weakSelf.buffer.removeValue(forKey: key)
                }
            }
            weakSelf.lock.unlock()
        }
    }
    
    @objc func didEnterBackground(_ noti: Notification) {
        requestQueue.cancelAllOperations()
        let next = (currentAnimatedImageIndex + 1) % totalFrameCount
        self.lock.lock()
        let keys = buffer.keys
        for key in keys where key != next { // keep the next frame for smoothly animation
            _ = buffer.removeValue(forKey: key)
        }
        self.lock.unlock()
    }

}

/// An operation for every single frame image fetch
fileprivate class AnimatedImageFetchOperation: Operation {
    weak var imageView: AnimatedImageView?
    var nextIndex: Int = 0
    var currentImage: (UIImage & AnimatedImageCodeable)?
    
    override func main() {
        guard let view = imageView else {
            return
        }
        if isCancelled {
            return
        }
        view.incrBufferCount += 1
        if view.incrBufferCount == 0 {
            view.calcMaxBufferCount()
        }
        if view.incrBufferCount > view.maxBufferCount {
            view.incrBufferCount = view.maxBufferCount
        }
        
        var index = nextIndex
        let max = view.incrBufferCount < 1 ? 1 : view.incrBufferCount
        let total = view.totalFrameCount
        
        for _ in 0..<max {
            
            if index >= total {
                index = 0
            }
            
            if isCancelled {
                break
            }
            view.lock.lock()
            let miss = view.buffer[index] == nil
            view.lock.unlock()
            
            if miss {
                let img = currentImage?.imageFrame(at: index, decompress: true)
                if isCancelled { break }
                view.lock.lock()
                view.buffer[index] = img
                view.lock.unlock()
            }
            index += 1
        }
        
    }
}
