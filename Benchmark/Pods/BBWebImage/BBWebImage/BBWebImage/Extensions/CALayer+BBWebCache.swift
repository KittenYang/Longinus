//
//  CALayer+BBWebCache.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/12/7.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

extension CALayer: BBWebCache {
    /// Sets image with resource, placeholder, custom opotions
    ///
    /// - Parameters:
    ///   - resource: image resource specifying how to download and cache image
    ///   - placeholder: placeholder image displayed when loading image
    ///   - options: options for some behaviors
    ///   - editor: editor specifying how to edit and cache image in memory
    ///   - progress: a closure called while image is downloading
    ///   - completion: a closure called when image loading is finished
    public func bb_setImage(with resource: BBWebCacheResource,
                            placeholder: UIImage? = nil,
                            options: BBWebImageOptions = .none,
                            editor: BBWebImageEditor? = nil,
                            progress: BBImageDownloaderProgress? = nil,
                            completion: BBWebImageManagerCompletion? = nil) {
        let setImage: BBSetImage = { [weak self] (image) in
            if let self = self { self.contents = image?.cgImage }
        }
        bb_setImage(with: resource,
                    placeholder: placeholder,
                    options: options,
                    editor: editor,
                    taskKey: bb_imageLoadTaskKey,
                    setImage: setImage,
                    progress: progress,
                    completion: completion)
    }
    
    /// Cancels image loading task
    public func bb_cancelImageLoadTask() {
        bb_webCacheOperation.task(forKey: bb_imageLoadTaskKey)?.cancel()
    }
    
    public var bb_imageLoadTaskKey: String { return classForCoder.description() }
}
