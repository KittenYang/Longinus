//
//  CALayer+Longinus.swift
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

extension CALayer: ImageWebCacheable {}
extension LonginusExtension where Base: CALayer {
    
    public var imageLoadTaskKey: String { return base.classForCoder.description() }
    
    public func setImage(with resource: ImageWebCacheResourceable?,
                         placeholder: UIImage? = nil,
                         options: ImageOptions = .none,
                         transformer: ImageTransformer? = nil,
                         progress: ImageDownloaderProgressBlock? = nil,
                         completion: ImageManagerCompletionBlock? = nil) {
        let setImageBlock: LonginusSetImageBlock = { [weak base] (image) in
            if let base = base { base.contents = image }
        }
        
        let setShowTransitionBlock: LonginusSetShowTransitionBlock = { [weak base] (image) in
            guard let base = base else {
                return
            }
            let transition = CATransition()
            transition.duration = 0.2
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.fade
            base.add(transition, forKey: LonginusImageFadeAnimationKey)
        }
        
        base.removeAnimation(forKey: LonginusImageFadeAnimationKey)
        
        base.setImage(with: resource,
                      placeholder: placeholder,
                      options: options,
                      transformer: transformer,
                      taskKey: imageLoadTaskKey,
                      setShowTransition: setShowTransitionBlock,
                      setImage: setImageBlock,
                      progress: progress,
                      completion: completion)
    }
    
    /// Cancels image loading task
    public func cancelImageLoadTask() {
        base.webCacheOperation.task(forKey: imageLoadTaskKey)?.cancel()
    }
    
}
