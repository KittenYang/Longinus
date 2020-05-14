//
//  ImageIOCoder.swift
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

public class ImageIOCoder: ImageCodeable {
    private var imageSource: CGImageSource?
    private var imageWidth: Int = 0
    private var imageHeight: Int = 0
    private var imageOrientation: UIImage.Orientation = .up
    
    public func canDecode(_ data: Data) -> Bool {
        switch data.lg.imageFormat {
        case .JPEG,.PNG:
            return true
        default:
            return false
        }
    }
    
    public func decodedImage(with data: Data) -> UIImage? {
        var image = UIImage(data: data)
        image?.lg.imageFormat = data.lg.imageFormat
        return image
    }
    
    public func decompressedImage(with image: UIImage, data: Data) -> UIImage? {
        guard let sourceImage = image.cgImage, let cgimage = ImageIOCoder.decompressedImage(sourceImage) else {
            return image
        }
        var finalImage = UIImage(cgImage: cgimage, scale: image.scale, orientation: image.imageOrientation)
        finalImage.lg.imageFormat = image.lg.imageFormat
        return finalImage
    }
    
    public func canEncode(_ format: ImageFormat) -> Bool {
        return true
    }
    
    public func encodedData(with image: UIImage, format: ImageFormat) -> Data? {
        guard let sourceImage = image.cgImage, let data = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
            return nil
        }
        var imageFormat = format
        if format == .unknown {
            imageFormat = sourceImage.lg.containsAlpha ? .PNG : .JPEG
        }
        if let destination = CGImageDestinationCreateWithData(data, imageFormat.UTType, 1, nil) {
            let properties = [kCGImagePropertyOrientation : image.imageOrientation.lg.cgImageOrientation.rawValue]
            CGImageDestinationAddImage(destination, sourceImage, properties as CFDictionary)
            if CGImageDestinationFinalize(destination) { return data as Data }
        }
        return nil
    }
    
    public func copy() -> ImageCodeable {
        return ImageIOCoder()
    }
    
}

public extension ImageIOCoder {
    static func decompressedImage(_ sourceImage: CGImage) -> CGImage? {
        return autoreleasepool { () -> CGImage? in
            let width = sourceImage.width
            let height = sourceImage.height
            var bitmapInfo = sourceImage.bitmapInfo
            bitmapInfo.remove(.alphaInfoMask)
            if sourceImage.lg.containsAlpha {
                bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            } else {
                bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
            }
            guard let context = CGContext(data: nil,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: sourceImage.bitsPerComponent,
                                          bytesPerRow: 0,
                                          space: lg_shareColorSpace,
                                          bitmapInfo: bitmapInfo.rawValue) else { return nil }
            context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return context.makeImage()
        }
    }
}

extension ImageIOCoder: ImageProgressiveCodeable {
    public func canIncrementallyDecode(_ data: Data) -> Bool {
        switch data.lg.imageFormat {
        case .JPEG, .PNG:
            return true
        default:
            return false
        }
    }
    
    public func incrementallyDecodedImage(with data: Data, finished: Bool) -> UIImage? {
        if imageSource == nil {
            imageSource = CGImageSourceCreateIncremental(nil)
        }
        guard let source = imageSource else { return nil }
        CGImageSourceUpdateData(source, data as CFData, finished)
        var image: UIImage?
        if imageWidth <= 0 || imageHeight <= 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString : AnyObject] {
            if let width = properties[kCGImagePropertyPixelWidth] as? Int {
                imageWidth = width
            }
            if let height = properties[kCGImagePropertyPixelHeight] as? Int {
                imageHeight = height
            }
            if let rawValue = properties[kCGImagePropertyOrientation] as? UInt32,
                let orientation = CGImagePropertyOrientation(rawValue: rawValue) {
                imageOrientation = orientation.lg.uiImageOrientation
            }
        }
        if imageWidth > 0 && imageHeight > 0,
            let cgimage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            image = UIImage(cgImage: cgimage, scale: 1, orientation: imageOrientation)
            image?.lg.imageFormat = data.lg.imageFormat
        }
        if finished {
            imageSource = nil
            imageWidth = 0
            imageHeight = 0
            imageOrientation = .up
        }
        return image
    }
    
}
    
    

