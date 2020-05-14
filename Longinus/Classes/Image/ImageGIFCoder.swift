//
//  ImageGIFCoder.swift
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
import MobileCoreServices

public class ImageGIFCoder {
    
    private var imageSource: CGImageSource?
    private var imageOrientation: UIImage.Orientation = .up
    
    public var imageData: Data? {
        didSet {
            if let data = imageData {
                imageSource = CGImageSourceCreateWithData(data as CFData, nil)
                if let source = imageSource,
                    let properties = CGImageSourceCopyProperties(source, nil) as? [CFString : Any],
                    let rawValue = properties[kCGImagePropertyOrientation] as? UInt32,
                    let orientation = CGImagePropertyOrientation(rawValue: rawValue) {
                    imageOrientation = orientation.lg.uiImageOrientation
                }
            } else {
                imageSource = nil
            }
        }
    }
    
    public var frameCount: Int? {
        if let source = imageSource {
            let count = CGImageSourceGetCount(source)
            if count > 0 {
                return count
            }
        }
        return nil
    }
    
    public var loopCount: Int? {
        if let source = imageSource,
            let properties = CGImageSourceCopyProperties(source, nil) as? [CFString : Any],
            let gifInfo = properties[kCGImagePropertyGIFDictionary] as? [CFString : Any],
            let count = gifInfo[kCGImagePropertyGIFLoopCount] as? Int  {
            return count
        }
        return nil
    }
    
}

extension ImageGIFCoder: ImageCodeable {
    
    public func canDecode(_ data: Data) -> Bool {
        return data.lg.imageFormat == .GIF
    }
    
    public func decodedImage(with data: Data) -> UIImage? {
        var image = AnimatedImage(lg_data: data, decoder: copy() as? AnimatedImageCodeable)
        image?.lg.imageFormat = data.lg.imageFormat
        return image
    }
    
    public func decompressedImage(with image: UIImage, data: Data) -> UIImage? {
        return nil
    }
    
    public func canEncode(_ format: ImageFormat) -> Bool {
        return format == .GIF
    }
    
    public func encodedData(with image: UIImage, format: ImageFormat) -> Data? {
        if format != .GIF { return nil }
        if let animatedImage = image as? AnimatedImage,
            animatedImage.lg.imageFormat == .GIF {
            return animatedImage.lg.originalImageData
        }
        var sourceImages: [CGImage] = []
        if let images = image.images {
            for frame in images {
                if let sourceImage = frame.cgImage {
                    sourceImages.append(sourceImage)
                }
            }
        }
        if sourceImages.isEmpty,
            let sourceImage = image.cgImage {
            sourceImages.append(sourceImage)
        }
        guard !sourceImages.isEmpty,
            let data = CFDataCreateMutable(kCFAllocatorDefault, 0),
            let destination = CGImageDestinationCreateWithData(data, kUTTypeGIF, sourceImages.count, nil) else { return nil }
        if sourceImages.count == 1 {
            CGImageDestinationAddImage(destination, sourceImages.first!, nil)
        } else {
            let properties: [CFString : Any] = [kCGImagePropertyGIFDictionary : [kCGImagePropertyGIFLoopCount : 0]]
            CGImageDestinationSetProperties(destination, properties as CFDictionary)
            
            let frameDuration = image.duration / Double(image.images!.count)
            let frameProperties: [CFString : Any] = [kCGImagePropertyGIFDictionary : [kCGImagePropertyGIFUnclampedDelayTime : frameDuration]]
            for sourceImage in sourceImages {
                CGImageDestinationAddImage(destination, sourceImage, frameProperties as CFDictionary)
            }
        }
        if CGImageDestinationFinalize(destination) { return data as Data }
        return nil
    }
    
    public func copy() -> ImageCodeable { return ImageGIFCoder() }
}

extension ImageGIFCoder: AnimatedImageCodeable {
    
    public func imageFrame(at index: Int, decompress: Bool) -> UIImage? {
        if let source = imageSource,
            let sourceImage = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceShouldCache : true] as CFDictionary) {
            if decompress {
                if let cgimage = ImageIOCoder.decompressedImage(sourceImage) {
                    return UIImage(cgImage: cgimage, scale: 1, orientation: imageOrientation)
                }
            } else {
                return UIImage(cgImage: sourceImage, scale: 1, orientation: imageOrientation)
            }
        }
        return nil
    }
    
    public func imageFrameSize(at index: Int) -> CGSize? {
        if let source = imageSource,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString : Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            width > 0,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            height > 0 {
            return CGSize(width: width, height: height)
        }
        return nil
    }
    
    public func duration(at index: Int) -> TimeInterval? {
        if let source = imageSource,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString : Any],
            let gifInfo = properties[kCGImagePropertyGIFDictionary] as? [CFString : Any] {
            var currentDuration: TimeInterval = -1
            if let d = gifInfo[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval {
                currentDuration = d
            } else if let d = gifInfo[kCGImagePropertyGIFDelayTime] as? TimeInterval {
                currentDuration = d
            }
            if currentDuration >= 0 {
                if currentDuration < 0.01 { currentDuration = 0.1 }
                return currentDuration
            }
        }
        return nil
    }
}
 
