//
//  UIButton+BBWebCache.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/9.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

extension UIButton: BBWebCache {
    /// Sets image with resource, placeholder, custom opotions
    ///
    /// - Parameters:
    ///   - resource: image resource specifying how to download and cache image
    ///   - state: button state to set image
    ///   - placeholder: placeholder image displayed when loading image
    ///   - options: options for some behaviors
    ///   - editor: editor specifying how to edit and cache image in memory
    ///   - progress: a closure called while image is downloading
    ///   - completion: a closure called when image loading is finished
    public func bb_setImage(with resource: BBWebCacheResource,
                            forState state: UIControl.State,
                            placeholder: UIImage? = nil,
                            options: BBWebImageOptions = .none,
                            editor: BBWebImageEditor? = nil,
                            progress: BBImageDownloaderProgress? = nil,
                            completion: BBWebImageManagerCompletion? = nil) {
        let setImage: BBSetImage = { [weak self] (image) in
            if let self = self { self.setImage(image, for: state) }
        }
        bb_setImage(with: resource,
                    placeholder: placeholder,
                    options: options,
                    editor: editor,
                    taskKey: bb_imageLoadTaskKey(forState: state),
                    setImage: setImage,
                    progress: progress,
                    completion: completion)
    }
    
    /// Cancels image loading task
    ///
    /// - Parameter state: button state to set image
    public func bb_cancelImageLoadTask(forState state: UIControl.State) {
        let key = bb_imageLoadTaskKey(forState: state)
        bb_webCacheOperation.task(forKey: key)?.cancel()
    }
    
    public func bb_imageLoadTaskKey(forState state: UIControl.State) -> String {
        return classForCoder.description() + "Image\(state.rawValue)"
    }
    
    /// Sets background image with resource, placeholder, custom opotions
    ///
    /// - Parameters:
    ///   - resource: image resource specifying how to download and cache image
    ///   - state: button state to set background image
    ///   - placeholder: placeholder image displayed when loading image
    ///   - options: options for some behaviors
    ///   - editor: editor specifying how to edit and cache image in memory
    ///   - progress: a closure called while image is downloading
    ///   - completion: a closure called when image loading is finished
    public func bb_setBackgroundImage(with resource: BBWebCacheResource,
                                      forState state: UIControl.State,
                                      placeholder: UIImage? = nil,
                                      options: BBWebImageOptions = .none,
                                      editor: BBWebImageEditor? = nil,
                                      progress: BBImageDownloaderProgress? = nil,
                                      completion: BBWebImageManagerCompletion? = nil) {
        let setImage: BBSetImage = { [weak self] (image) in
            if let self = self { self.setBackgroundImage(image, for: state) }
        }
        bb_setImage(with: resource,
                    placeholder: placeholder,
                    options: options,
                    editor: editor,
                    taskKey: bb_backgroundImageLoadTaskKey(forState: state),
                    setImage: setImage,
                    progress: progress,
                    completion: completion)
    }
    
    /// Cancels background image loading task
    ///
    /// - Parameter state: button state to set background image
    public func bb_cancelBackgroundImageLoadTask(forState state: UIControl.State) {
        let key = bb_backgroundImageLoadTaskKey(forState: state)
        bb_webCacheOperation.task(forKey: key)?.cancel()
    }
    
    public func bb_backgroundImageLoadTaskKey(forState state: UIControl.State) -> String {
        return classForCoder.description() + "BackgroundImage\(state.rawValue)"
    }
}
