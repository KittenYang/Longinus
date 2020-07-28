//
//  BBImageCoder.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/3.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

/// BBImageCoder defines image decoding and encoding behaviors
public protocol BBImageCoder: AnyObject {
    /// Image coder can decode data or not
    ///
    /// - Parameter data: data to decode
    /// - Returns: true if coder can decode data, or false if can not
    func canDecode(_ data: Data) -> Bool
    
    /// Decodes image with data
    ///
    /// - Parameter data: data to decode
    /// - Returns: decoded image, or nil if decoding fails
    func decodedImage(with data: Data) -> UIImage?
    
    /// Decompresses image with data
    ///
    /// - Parameters:
    ///   - image: image to decompress
    ///   - data: image data
    /// - Returns: decompressed image, or nil if decompressing fails
    func decompressedImage(with image: UIImage, data: Data) -> UIImage?
    
    /// Image coder can encode image format or not
    ///
    /// - Parameter format: image format to encode
    /// - Returns: true if coder can encode image format, or false if can not
    func canEncode(_ format: BBImageFormat) -> Bool
    
    /// Encodes image to specified format
    ///
    /// - Parameters:
    ///   - image: image to encode
    ///   - format: image format to encode
    /// - Returns: encoded data, or nil if encoding fails
    func encodedData(with image: UIImage, format: BBImageFormat) -> Data?
    
    /// Copies image coder
    ///
    /// - Returns: new image coder
    func copy() -> BBImageCoder
}

/// BBImageProgressiveCoder defines image incremental decoding behaviors
public protocol BBImageProgressiveCoder: BBImageCoder {
    /// Image coder can decode data incrementally or not
    ///
    /// - Parameter data: data to decode
    /// - Returns: true if image coder can decode data incrementally, or false if can not
    func canIncrementallyDecode(_ data: Data) -> Bool
    
    /// Decodes data incrementally
    ///
    /// - Parameters:
    ///   - data: data to decode
    ///   - finished: whether downloading is finished
    /// - Returns: decoded image, or nil if decoding fails
    func incrementallyDecodedImage(with data: Data, finished: Bool) -> UIImage?
}

/// BBAnimatedImageCoder defines animated image decoding behaviors
public protocol BBAnimatedImageCoder: BBImageCoder {
    /// Image data to decode
    var imageData: Data? { get set }
    
    /// Number of image frames, or nil if fail to get the value
    var frameCount: Int? { get }
    
    /// Number of times to repeat the animation.
    /// Value 0 specifies to repeat the animation indefinitely.
    /// Value nil means failing to get the value.
    var loopCount: Int? { get }
    
    /// Gets image frame at specified index
    ///
    /// - Parameters:
    ///   - index: frame index
    ///   - decompress: whether to decompress image or not
    /// - Returns: image frame, or nil if fail
    func imageFrame(at index: Int, decompress: Bool) -> UIImage?
    
    /// Gets image frame size at specified index
    ///
    /// - Parameter index: frame index
    /// - Returns: image frame size, or nil if fail
    func imageFrameSize(at index: Int) -> CGSize?
    
    /// Gets image frame duration at specified index
    ///
    /// - Parameter index: frame index
    /// - Returns: image frame duration, or nil if fail
    func duration(at index: Int) -> TimeInterval?
}

/// BBImageCoderManager manages image coders for diffent image formats
public class BBImageCoderManager {
    /// Image coders.
    /// Getting and setting are thread safe.
    /// Set this property with custom image coders to custom image encoding and decoding.
    public var coders: [BBImageCoder] {
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
    private var _coders: [BBImageCoder]
    private var coderLock: pthread_mutex_t
    
    init() {
        _coders = [BBWebImageImageIOCoder(), BBWebImageGIFCoder()]
        coderLock = pthread_mutex_t()
        pthread_mutex_init(&coderLock, nil)
    }
}

extension BBImageCoderManager: BBImageCoder {
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
    
    public func canEncode(_ format: BBImageFormat) -> Bool {
        let currentCoders = coders
        for coder in currentCoders where coder.canEncode(format) {
            return true
        }
        return false
    }
    
    public func encodedData(with image: UIImage, format: BBImageFormat) -> Data? {
        let currentCoders = coders
        for coder in currentCoders where coder.canEncode(format) {
            return coder.encodedData(with: image, format: format)
        }
        return nil
    }
    
    public func copy() -> BBImageCoder {
        let newObj = BBImageCoderManager()
        var newCoders: [BBImageCoder] = []
        let currentCoders = coders
        for coder in currentCoders {
            newCoders.append(coder.copy())
        }
        newObj.coders = newCoders
        return newObj
    }
}

extension BBImageCoderManager: BBImageProgressiveCoder {
    public func canIncrementallyDecode(_ data: Data) -> Bool {
        let currentCoders = coders
        for coder in currentCoders {
            if let progressiveCoder = coder as? BBImageProgressiveCoder,
                progressiveCoder.canIncrementallyDecode(data) {
                return true
            }
        }
        return false
    }
    
    public func incrementallyDecodedImage(with data: Data, finished: Bool) -> UIImage? {
        let currentCoders = coders
        for coder in currentCoders {
            if let progressiveCoder = coder as? BBImageProgressiveCoder,
                progressiveCoder.canIncrementallyDecode(data) {
                return progressiveCoder.incrementallyDecodedImage(with: data, finished: finished)
            }
        }
        return nil
    }
}
