//
//  AnimatedImageView.swift
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
    

import Foundation

enum AnimatedImageViewType {
    case none
    case image
    case hilightedImage
    case animationImages
    case hilightedAnimationImages
}

private var autoStartAnimationKey: Void?
private var currentFrameIndexKey: Void?

extension LonginusExtension where Base: AnimatedImageView {
    public var autoStartAnimation: Bool {
        get {
            let box: Box<Bool>? = getAssociatedObject(base, &autoStartAnimationKey)
            return box?.value ?? false
        }
        set {
            let box = Box(newValue)
            setRetainedAssociatedObject(base, &autoStartAnimationKey, box)
        }
    }
    
    public var animationDurationScale: Double {
        get { return base.animationDurationScale }
        set { if newValue > 0 { base.animationDurationScale = newValue } }
    }
    
    public var runLoopMode: RunLoop.Mode {
        get { return base.runLoopMode }
        set {
            if runLoopMode == newValue { return }
            if let oldLink = base.displayLink {
                // If remove old run loop mode and add new run loop mode, the animation will pause a while in iOS 8.
                // So create a new display link here.
                let isPaused = oldLink.isPaused
                oldLink.invalidate()
                let link = CADisplayLink(target: LonginusWeakProxy(target: base), selector: #selector(base.displayLinkRefreshed(_:)))
                link.isPaused = isPaused
                link.add(to: .main, forMode: newValue)
                base.displayLink = link
            }
            runLoopMode = newValue
        }
    }
    
    public fileprivate(set) var currentFrameIndex: Int {
        get {
            let box: Box<Int>? = getAssociatedObject(base, &currentFrameIndexKey)
            return box?.value ?? 0
        }
        set {
            let box = Box(newValue)
            setRetainedAssociatedObject(base, &currentFrameIndexKey, box)
        }
    }
    
    
    /// Sets the current animated image frame index
    ///
    /// - Parameters:
    ///   - index: frame index
    ///   - decodeIfNeeded: whether to decode or edit image synchronously if no cached image found
    /// - Returns: true if succeed, or false if fail
    @discardableResult
    public mutating func setCurrentFrameIndex(_ index: Int, decodeIfNeeded: Bool) -> Bool {
        guard let currentImage = base.imageForCurrentType as? AnimatedImage,
            let cgimage = currentImage.lg.imageFrame(at: index, decodeIfNeeded: decodeIfNeeded)?.cgImage else { return false }
        base.currentLayerContent = cgimage
        base.layer.setNeedsDisplay()
        currentFrameIndex = index
        base.accumulatedTime = 0
        base.shouldUpdateLayer = false
        if let link = base.displayLink, !link.isPaused {
            let nextIndex = (currentFrameIndex + 1) % currentImage.lg.frameCount
            currentImage.lg.preloadImageFrame(fromIndex: nextIndex)
        }
        return true
    }
    
    
}

public class AnimatedImageView: UIImageView {

    
    /// Set a AnimatedImage object to play animation
    public override var image: UIImage? {
        get { return super.image }
        set {
            if super.image == newValue { return }
            setImage(newValue, withType: .image)
        }
    }
    
    /// Set a AnimatedImage object to play animation
    public override var highlightedImage: UIImage? {
        get { return super.highlightedImage }
        set {
            if super.highlightedImage == newValue { return }
            setImage(newValue, withType: .hilightedImage)
        }
    }
    
    public override var animationImages: [UIImage]? {
        get { return super.animationImages }
        set {
            if super.animationImages == newValue { return }
            setImage(newValue, withType: .animationImages)
        }
    }
    
    public override var highlightedAnimationImages: [UIImage]? {
        get { return super.highlightedAnimationImages }
        set {
            if super.highlightedAnimationImages == newValue { return }
            setImage(newValue, withType: .hilightedAnimationImages)
        }
    }
    
    public override var isAnimating: Bool {
        switch currentType {
        case .none: return false
        case .image, .hilightedImage:
            if let link = displayLink { return !link.isPaused }
            return false
        default: return super.isAnimating
        }
    }
    
    private var currentType: AnimatedImageViewType {
        var type: AnimatedImageViewType = .none
        if isHighlighted {
            if let count = highlightedAnimationImages?.count, count > 0 { type = .hilightedAnimationImages }
            else if highlightedImage != nil { type = .hilightedImage }
        }
        if type == .none {
            if let count = animationImages?.count, count > 0 { type = .animationImages }
            else if image != nil { type = .image }
        }
        return type
    }
    
    fileprivate var imageForCurrentType: Any? { return image(forType: currentType) }
    
    fileprivate var displayLink: CADisplayLink?
    fileprivate var animationDurationScale: Double = 1
    fileprivate var runLoopMode: RunLoop.Mode = .commonModes
    fileprivate var shouldUpdateLayer: Bool = true
    fileprivate var loopCount: Int = 0
    fileprivate var accumulatedTime: TimeInterval = 0
    fileprivate var currentLayerContent: CGImage?
    
    deinit {
        displayLink?.invalidate()
    }
    
    private func setImage(_ image: Any?, withType type: AnimatedImageViewType) {
        stopAnimating()
        if displayLink != nil { resetAnimation() }
        let animatedImage = image as? AnimatedImage
        switch type {
        case .none: break
        case .image:
            let old = super.image as? AnimatedImage
            super.image = image as? UIImage
            old?.lg.didRemoveFromView(self)
        case .hilightedImage:
            let old = super.highlightedImage as? AnimatedImage
            super.highlightedImage = image as? UIImage
            old?.lg.didRemoveFromView(self)
        case .animationImages: super.animationImages = image as? [UIImage]
        case .hilightedAnimationImages: super.highlightedAnimationImages = image as? [UIImage]
        }
        animatedImage?.lg.didAddToView(self)
        animatedImage?.lg.updateCacheSizeIfNeeded()
        didMove()
    }
    
    private func resetAnimation() {
        loopCount = 0
        var m_lg = lg
        m_lg.currentFrameIndex = 0
        accumulatedTime = 0
        currentLayerContent = nil
        shouldUpdateLayer = true
    }
    
    @objc fileprivate func displayLinkRefreshed(_ link: CADisplayLink) {
        guard let currentImage = imageForCurrentType as? AnimatedImage else { return }
        if shouldUpdateLayer,
            let cgimage = currentImage.lg.imageFrame(at: lg.currentFrameIndex, decodeIfNeeded: (lg.currentFrameIndex == 0))?.cgImage {
            currentLayerContent = cgimage
            layer.setNeedsDisplay()
            shouldUpdateLayer = false
        }
        let nextIndex = (lg.currentFrameIndex + 1) % currentImage.lg.frameCount
        currentImage.lg.preloadImageFrame(fromIndex: nextIndex)
        accumulatedTime += link.duration // multiply frameInterval if frameInterval is not 1
        if var duration = currentImage.lg.duration(at: lg.currentFrameIndex) {
            duration *= animationDurationScale
            if accumulatedTime >= duration {
                var m_lg = lg
                m_lg.currentFrameIndex = nextIndex
                accumulatedTime -= duration
                shouldUpdateLayer = true
                if (animationRepeatCount > 0 || currentImage.lg.loopCount > 0) && lg.currentFrameIndex == 0 {
                    loopCount += 1
                    if (animationRepeatCount > 0 && loopCount >= animationRepeatCount) ||
                        (currentImage.lg.loopCount > 0 && loopCount >= currentImage.lg.loopCount) {
                        stopAnimating()
                        resetAnimation()
                    }
                }
            }
        }
    }
    
    private func image(forType type: AnimatedImageViewType) -> Any? {
        switch type {
        case .none: return nil
        case .image: return image
        case .hilightedImage: return highlightedImage
        case .animationImages: return animationImages
        case .hilightedAnimationImages: return highlightedAnimationImages
        }
    }

    
    public override func startAnimating() {
        switch currentType {
        case .image, .hilightedImage:
            if let link = displayLink {
                if link.isPaused { link.isPaused = false }
            } else {
                let link = CADisplayLink(target: LonginusWeakProxy(target: self), selector: #selector(displayLinkRefreshed(_:)))
                link.add(to: .main, forMode: runLoopMode)
                displayLink = link
            }
        default:
            super.startAnimating()
        }
    }
    
    public override func stopAnimating() {
        super.stopAnimating()
        displayLink?.isPaused = true
    }
    
    public override func didMoveToSuperview() {
        didMove()
    }
    
    public override func didMoveToWindow() {
        didMove()
    }
    
    private func didMove() {
        if lg.autoStartAnimation {
            if superview != nil && window != nil {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
    
    // MARK: - Layer delegate
    
    public override func display(_ layer: CALayer) {
        if let content = currentLayerContent { layer.contents = content }
    }
}
