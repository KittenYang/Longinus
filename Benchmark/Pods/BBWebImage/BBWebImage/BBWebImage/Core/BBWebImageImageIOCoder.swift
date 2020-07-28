//
//  BBWebImageImageIOCoder.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/8.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

public class BBWebImageImageIOCoder: BBImageCoder {
    private var imageSource: CGImageSource?
    private var imageWidth: Int
    private var imageHeight: Int
    private var imageOrientation: UIImage.Orientation
    
    public init() {
        imageWidth = 0
        imageHeight = 0
        imageOrientation = .up
    }
    
    public func canDecode(_ data: Data) -> Bool {
        switch data.bb_imageFormat {
        case .JPEG, .PNG:
            return true
        default:
            return false
        }
    }
    
    public func decodedImage(with data: Data) -> UIImage? {
        let image = UIImage(data: data)
        image?.bb_imageFormat = data.bb_imageFormat
        return image
    }
    
    public func decompressedImage(with image: UIImage, data: Data) -> UIImage? {
        guard let sourceImage = image.cgImage,
            let cgimage = BBWebImageImageIOCoder.decompressedImage(sourceImage) else { return image }
        let finalImage = UIImage(cgImage: cgimage, scale: image.scale, orientation: image.imageOrientation)
        finalImage.bb_imageFormat = image.bb_imageFormat
        return finalImage
    }
    
    public static func decompressedImage(_ sourceImage: CGImage) -> CGImage? {
        return autoreleasepool { () -> CGImage? in
            let width = sourceImage.width
            let height = sourceImage.height
            var bitmapInfo = sourceImage.bitmapInfo
            bitmapInfo.remove(.alphaInfoMask)
            if sourceImage.bb_containsAlpha {
                bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            } else {
                bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
            }
            guard let context = CGContext(data: nil,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: sourceImage.bitsPerComponent,
                                          bytesPerRow: 0,
                                          space: bb_shareColorSpace,
                                          bitmapInfo: bitmapInfo.rawValue) else { return nil }
            context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return context.makeImage()
        }
    }
    
    public func canEncode(_ format: BBImageFormat) -> Bool {
        return true
    }
    
    public func encodedData(with image: UIImage, format: BBImageFormat) -> Data? {
        guard let sourceImage = image.cgImage,
            let data = CFDataCreateMutable(kCFAllocatorDefault, 0) else { return nil }
        var imageFormat = format
        if format == .unknown { imageFormat = sourceImage.bb_containsAlpha ? .PNG : .JPEG }
        if let destination = CGImageDestinationCreateWithData(data, imageFormat.UTType, 1, nil) {
            let properties = [kCGImagePropertyOrientation : image.imageOrientation.bb_CGImageOrientation.rawValue]
            CGImageDestinationAddImage(destination, sourceImage, properties as CFDictionary)
            if CGImageDestinationFinalize(destination) { return data as Data }
        }
        return nil
    }
    
    public func copy() -> BBImageCoder { return BBWebImageImageIOCoder() }
}

extension BBWebImageImageIOCoder: BBImageProgressiveCoder {
    public func canIncrementallyDecode(_ data: Data) -> Bool {
        switch data.bb_imageFormat {
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
                imageOrientation = orientation.bb_UIImageOrientation
            }
        }
        if imageWidth > 0 && imageHeight > 0,
            let cgimage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            image = UIImage(cgImage: cgimage, scale: 1, orientation: imageOrientation)
            image?.bb_imageFormat = data.bb_imageFormat
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
