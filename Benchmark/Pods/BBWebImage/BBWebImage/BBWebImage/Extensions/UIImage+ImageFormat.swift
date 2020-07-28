//
//  UIImage+ImageFormat.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/8.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

private var imageFormatKey: Void?
private var imageDataKey: Void?
private var imageEditKey: Void?

public extension UIImage {
    var bb_imageFormat: BBImageFormat? {
        get { return objc_getAssociatedObject(self, &imageFormatKey) as? BBImageFormat }
        set { objc_setAssociatedObject(self, &imageFormatKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var bb_imageEditKey: String? {
        get { return objc_getAssociatedObject(self, &imageEditKey) as? String }
        set { objc_setAssociatedObject(self, &imageEditKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var bb_bytes: Int64 { return Int64(size.width * size.height * scale) }
}

public extension CGImage {
    var bb_containsAlpha: Bool { return !(alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast) }
    var bb_bytes: Int { return max(1, height * bytesPerRow) }
}

extension CGImagePropertyOrientation {
    var bb_UIImageOrientation: UIImage.Orientation {
        switch self {
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

extension UIImage.Orientation {
    var bb_CGImageOrientation: CGImagePropertyOrientation {
        switch self {
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
