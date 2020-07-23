//
//  Image.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/11.
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
    

import UIKit

extension UIImage: CacheCostCalculable {
    /// Cost of an image
    public var cacheCost: Int64 { return lg.bytes }
}

private var imageFormatKey: Void?
private var imageEditKey: Void?

extension LonginusExtension where Base: UIImage {
    var cgImage: CGImage? { return base.cgImage }
    var size: CGSize { return base.size }
    var scale: CGFloat { return base.scale }
    
    // Bitmap memory cost with bytes
    var bytes: Int64 {
        guard let cgImage = cgImage else {
            return 1
        }
        return Int64(max(1, cgImage.height * cgImage.bytesPerRow))
    }
    
    var imageFormat: ImageFormat? {
        get { return getAssociatedObject(base, &imageFormatKey) }
        set { setRetainedAssociatedObject(base, &imageFormatKey, newValue) }
    }
    
    var lgImageEditKey: String? {
        get { return getAssociatedObject(base, &imageEditKey) }
        set { setRetainedAssociatedObject(base, &imageEditKey, newValue) }
    }
    
}

extension LonginusExtension where Base: CGImage {
    var containsAlpha: Bool {
        return !(base.alphaInfo == .none || base.alphaInfo == .noneSkipFirst || base.alphaInfo == .noneSkipLast)
    }
}

extension LonginusExtension where Base == UIImage.Orientation {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch base {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        default: return .up
        }
    }
}

extension LonginusExtension where Base == CGImagePropertyOrientation {
    var uiImageOrientation: UIImage.Orientation {
        switch base {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .downMirrored
        default: return .up
        }
    }
}
