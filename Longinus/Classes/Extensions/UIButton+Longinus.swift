//
//  UIButton+Longinus.swift
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

extension UIButton: ImageWebCacheable {}
extension LonginusExtension where Base: UIButton {
    
    public func imageLoadTaskKey(forState state: UIControl.State) -> String {
        return base.classForCoder.description() + "Image\(state.rawValue)"
    }
    
    public func setImage(with resource: ImageWebCacheResourceable?,
                         forState state: UIControl.State,
                         placeholder: UIImage? = nil,
                         options: ImageOptions = .none,
                         editor: ImageTransformer? = nil,
                         progress: ImageDownloaderProgressBlock? = nil,
                         completion: ImageManagerCompletionBlock? = nil) {
        let setImageBlock: LonginusSetImageBlock = { [weak base] (image) in
            if let base = base { base.setImage(image, for: state) }
        }
        
        let setShowTransitionBlock: LonginusSetShowTransitionBlock = { [weak base] (image) in
            guard let base = base else {
                return
            }
            if base.state == state {
                let transition = CATransition()
                transition.duration = 0.2
                transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                transition.type = kCATransitionFade
                base.layer.add(transition, forKey: LonginusImageFadeAnimationKey)
            }
        }
        
        base.layer.removeAnimation(forKey: LonginusImageFadeAnimationKey)
        
        base.setImage(with: resource,
                 placeholder: placeholder,
                 options: options,
                 editor: editor,
                 taskKey: imageLoadTaskKey(forState: state),
                 setShowTransition: setShowTransitionBlock,
                 setImage: setImageBlock,
                 progress: progress,
                 completion: completion)
    }
    
    public func cancelImageLoadTask(forState state: UIControl.State) {
        let key = imageLoadTaskKey(forState: state)
        base.webCacheOperation.task(forKey: key)?.cancel()
    }
    
    public func setBackgroundImage(with resource: ImageWebCacheResourceable,
                                   forState state: UIControl.State,
                                   placeholder: UIImage? = nil,
                                   options: ImageOptions = .none,
                                   editor: ImageTransformer? = nil,
                                   progress: ImageDownloaderProgressBlock? = nil,
                                   completion: ImageManagerCompletionBlock? = nil) {
        let setImage: LonginusSetImageBlock = { [weak base] (image) in
            if let base = base { base.setBackgroundImage(image, for: state) }
        }
        
        let setShowTransitionBlock: LonginusSetShowTransitionBlock = { [weak base] (image) in
            guard let base = base else {
                return
            }
            if base.state == state {
                let transition = CATransition()
                transition.duration = 0.2
                transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                transition.type = kCATransitionFade
                base.layer.add(transition, forKey: LonginusImageFadeAnimationKey)
            }
        }
        
        base.layer.removeAnimation(forKey: LonginusImageFadeAnimationKey)
        
        base.setImage(with: resource,
                      placeholder: placeholder,
                      options: options,
                      editor: editor,
                      taskKey: backgroundImageLoadTaskKey(forState: state),
                      setShowTransition: setShowTransitionBlock,
                      setImage: setImage,
                      progress: progress,
                      completion: completion)
    }
    
    public func cancelBackgroundImageLoadTask(forState state: UIControl.State) {
        let key = backgroundImageLoadTaskKey(forState: state)
        base.webCacheOperation.task(forKey: key)?.cancel()
    }
    
    public func backgroundImageLoadTaskKey(forState state: UIControl.State) -> String {
        return base.classForCoder.description() + "BackgroundImage\(state.rawValue)"
    }

}
