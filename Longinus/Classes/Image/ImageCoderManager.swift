//
//  ImageCoderManager.swift
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

public class ImageCoderManager {
    
    private var _coders: [ImageCodeable]
    private var coderLock: pthread_mutex_t
    
    public var coders: [ImageCodeable] {
        get {
            pthread_mutex_lock(&coderLock)
            let currentCoders = _coders
            pthread_mutex_unlock(&coderLock)
            return currentCoders
        }
        set {
            pthread_mutex_lock(&coderLock)
            _coders = newValue
            pthread_mutex_unlock(&coderLock)
        }
    }
    
    init() {
        _coders = [ImageIOCoder(), ImageGIFCoder()]
        coderLock = pthread_mutex_t()
        pthread_mutex_init(&coderLock, nil)
    }
    
}

extension ImageCoderManager: ImageCodeable {
    public func canDecode(_ data: Data) -> Bool {
        let currentCoders = coders
        for coder in currentCoders where coder.canDecode(data) {
            return true
        }
        return false
    }
    
    public func decodedImage(with data: Data) -> UIImage? {
        let currentCoders = coders
        for coder in currentCoders where coder.canDecode(data) {
            return coder.decodedImage(with: data)
        }
        return nil
    }
    
    public func decompressedImage(with image: UIImage, data: Data) -> UIImage? {
        let currentCoders = coders
        for coder in currentCoders where coder.canDecode(data) {
            return coder.decompressedImage(with: image, data: data)
        }
        return nil
    }
    
    public func canEncode(_ format: ImageFormat) -> Bool {
        let currentCoders = coders
        for coder in currentCoders where coder.canEncode(format) {
            return true
        }
        return false
    }
    
    public func encodedData(with image: UIImage, format: ImageFormat) -> Data? {
        let currentCoders = coders
        for coder in currentCoders where coder.canEncode(format) {
            return coder.encodedData(with: image, format: format)
        }
        return nil
    }
    
    public func copy() -> ImageCodeable {
        let newObj = ImageCoderManager()
        var newCoders: [ImageCodeable] = []
        let currentCoders = coders
        for coder in currentCoders {
            newCoders.append(coder.copy())
        }
        newObj.coders = newCoders
        return newObj
    }
}

extension ImageCoderManager: ImageProgressiveCodeable {
    public func canIncrementallyDecode(_ data: Data) -> Bool {
        let currentCoders = coders
        for coder in currentCoders {
            if let progressiveCoder = coder as? ImageProgressiveCodeable,
                progressiveCoder.canIncrementallyDecode(data) {
                return true
            }
        }
        return false
    }
    
    public func incrementallyDecodedImage(with data: Data, finished: Bool) -> UIImage? {
        let currentCoders = coders
        for coder in currentCoders {
            if let progressiveCoder = coder as? ImageProgressiveCodeable,
                progressiveCoder.canIncrementallyDecode(data) {
                return progressiveCoder.incrementallyDecodedImage(with: data, finished: finished)
            }
        }
        return nil
    }
}
