//
//  BBWebImageEditor.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/10.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

public typealias BBWebImageEditMethod = (UIImage) -> UIImage?

public let bb_shareColorSpace = CGColorSpaceCreateDeviceRGB()
public let bb_ScreenScale = UIScreen.main.scale

private var shareCIContext: CIContext?
public var bb_shareCIContext: CIContext {
    var localContext = shareCIContext
    if localContext == nil {
        if #available(iOS 9.0, *) {
            localContext = CIContext(options: [CIContextOption.workingColorSpace : bb_shareColorSpace])
        } else {
            // CIContext.init(options:) will crash in iOS 8. So use other init
            localContext = CIContext(eaglContext: EAGLContext(api: .openGLES2)!, options: [CIContextOption.workingColorSpace : bb_shareColorSpace])
        }
        shareCIContext = localContext
    }
    return localContext!
}

public func bb_clearCIContext() { shareCIContext = nil }

/// Creates a BBWebImageEditor to crop image
///
/// - Parameter rect: rect to crop, mesured in points
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorCrop(with rect: CGRect) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_croppedImage(with: rect) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.crop.rect=\(rect)", edit: edit)
}

/// Creates a BBWebImageEditor to resize image to the specific size
///
/// - Parameter size: size to resize
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorResize(with size: CGSize) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_resizedImage(with: size) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.resize.size=\(size)", edit: edit)
}

/// Creates a BBWebImageEditor to resize image with view size and content mode.
/// Some portion of the image may be clipped.
/// Use the method to display the valid portion of image to save memory.
///
/// - Parameters:
///   - displaySize: view size
///   - contentMode: view content mode
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorResize(with displaySize: CGSize, contentMode: UIView.ContentMode) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_resizedImage(with: displaySize, contentMode: contentMode) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.resize.size=\(displaySize),contentMode=\(contentMode.rawValue)", edit: edit)
}

/// Creates a BBWebImageEditor to resize image with view size and fill content mode.
/// Some portion of the image may be clipped.
/// Use the method to display the valid portion of image to save memory.
///
/// - Parameters:
///   - displaySize: view size
///   - fillContentMode: fill content mode specifying how content fills its view
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorResize(with displaySize: CGSize, fillContentMode: UIView.BBFillContentMode) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_resizedImage(with: displaySize, fillContentMode: fillContentMode) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.resize.size=\(displaySize),fillContentMode=\(fillContentMode)", edit: edit)
}

/// Creates a BBWebImageEditor to rotate image
///
/// - Parameters:
///   - angle: angle (degree) to rotate
///   - fitSize: true to change image size to fit rotated image, false to keep image size
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorRotate(withAngle angle: CGFloat, fitSize: Bool) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_rotatedImage(withAngle: angle, fitSize: fitSize) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.rotate.angle=\(angle),fitSize=\(fitSize)", edit: edit)
}

/// Creates a BBWebImageEditor to flip image horizontally and/or vertically
///
/// - Parameters:
///   - horizontal: whether to flip horizontally or not
///   - vertical: whether to flip vertically or not
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorFlip(withHorizontal horizontal: Bool, vertical: Bool) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_flippedImage(withHorizontal: horizontal, vertical: vertical) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.flip.horizontal=\(horizontal),vertical=\(vertical)", edit: edit)
}

/// Creates a BBWebImageEditor to tint image with color
///
/// - Parameters:
///   - color: color to draw
///   - blendMode: blend mode to use when compositing the image
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorTint(with color: UIColor, blendMode: CGBlendMode = .normal) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_tintedImage(with: color, blendMode: blendMode) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.tint.color=\(color),blendMode=\(blendMode.rawValue)", edit: edit)
}

/// Creates a BBWebImageEditor to tint image with gradient color
///
/// - Parameters:
///   - colors: colors to draw
///   - locations: location of each color provided in colors. Each location must be a CGFloat value in the range of 0 to 1
///   - start: starting point (x and y are in the range of 0 to 1) of the gradient
///   - end: ending point (x and y are in the range of 0 to 1) of the gradient
///   - blendMode: blend mode to use when compositing the image
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorGradientlyTint(with colors: [UIColor],
                                         locations: [CGFloat],
                                         start: CGPoint = CGPoint(x: 0.5, y: 0),
                                         end: CGPoint = CGPoint(x: 0.5, y: 1),
                                         blendMode: CGBlendMode = .normal) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_gradientlyTintedImage(with: colors,
                                                             locations: locations,
                                                             start: start,
                                                             end: end,
                                                             blendMode: blendMode) {
            return currentImage
        }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.gradientlyTint.colors=\(colors),locations=\(locations),start=\(start),end=\(end),blendMode=\(blendMode.rawValue)", edit: edit)
}

/// Creates an image overlaid by another image
///
/// - Parameters:
///   - overlayImage: image at the top as an overlay
///   - blendMode: blend mode to use when compositing the image
///   - alpha: opacity of overlay image, specified as a value between 0 (totally transparent) and 1 (fully opaque)
/// - Returns: an overlaid image

/// Creates a BBWebImageEditor to overlay image with another image
///
/// - Parameters:
///   - overlayImage: image at the top as an overlay
///   - blendMode: blend mode to use when compositing the image
///   - alpha: opacity of overlay image, specified as a value between 0 (totally transparent) and 1 (fully opaque)
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorOverlay(with overlayImage: UIImage, blendMode: CGBlendMode = .normal, alpha: CGFloat) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_overlaidImage(with: overlayImage, blendMode: blendMode, alpha: alpha) { return currentImage }
        return image
    }
    return BBWebImageEditor(key: "com.Kaibo.BBWebImage.overlay.image=\(overlayImage),blendMode=\(blendMode.rawValue),alpha=\(alpha)", edit: edit)
}

/// Creates a BBWebImageEditor for common use
///
/// - Parameters:
///   - displaySize: size of view displaying image
///   - fillContentMode: fill content mode specifying how content fills its view
///   - maxResolution: an expected maximum resolution of decoded image
///   - corner: how many image corners are drawn
///   - cornerRadius: corner radius of image, in view's coordinate
///   - borderWidth: border width of image, in view's coordinate
///   - borderColor: border color of image
///   - backgroundColor: background color of image
/// - Returns: a BBWebImageEditor variable
public func bb_imageEditorCommon(with displaySize: CGSize,
                                 fillContentMode: UIView.BBFillContentMode = .center,
                                 maxResolution: Int = 0,
                                 corner: UIRectCorner = UIRectCorner(rawValue: 0),
                                 cornerRadius: CGFloat = 0,
                                 borderWidth: CGFloat = 0,
                                 borderColor: UIColor? = nil,
                                 backgroundColor: UIColor? = nil) -> BBWebImageEditor {
    let edit: BBWebImageEditMethod = { (image) in
        if let currentImage = image.bb_commonEditedImage(with: displaySize,
                                                         fillContentMode: fillContentMode,
                                                         maxResolution: maxResolution,
                                                         corner: corner,
                                                         cornerRadius: cornerRadius,
                                                         borderWidth: borderWidth,
                                                         borderColor: borderColor,
                                                         backgroundColor: backgroundColor) {
            return currentImage
        }
        return image
    }
    let key = "com.Kaibo.BBWebImage.common.displaySize=\(displaySize),fillContentMode=\(fillContentMode),maxResolution=\(maxResolution),corner=\(corner),cornerRadius=\(cornerRadius),borderWidth=\(borderWidth),borderColor=\(borderColor?.description ?? "nil"),backgroundColor=\(backgroundColor?.description ?? "nil")"
    return BBWebImageEditor(key: key, edit: edit)
}

public func bb_borderPath(with size: CGSize, corner: UIRectCorner, cornerRadius: CGFloat, borderWidth: CGFloat) -> UIBezierPath {
    let halfBorderWidth = borderWidth / 2
    let path = UIBezierPath()
    if corner.isSuperset(of: .topLeft) {
        path.move(to: CGPoint(x: halfBorderWidth, y: cornerRadius + halfBorderWidth))
        path.addArc(withCenter: CGPoint(x: cornerRadius + halfBorderWidth, y: cornerRadius + halfBorderWidth),
                    radius: cornerRadius,
                    startAngle: CGFloat.pi,
                    endAngle: CGFloat.pi * 3 / 2,
                    clockwise: true)
    } else {
        path.move(to: CGPoint(x: halfBorderWidth, y: halfBorderWidth))
    }
    if corner.isSuperset(of: .topRight) {
        path.addLine(to: CGPoint(x: size.width - cornerRadius - halfBorderWidth, y: halfBorderWidth))
        path.addArc(withCenter: CGPoint(x: size.width - cornerRadius - halfBorderWidth, y: cornerRadius + halfBorderWidth),
                    radius: cornerRadius,
                    startAngle: CGFloat.pi * 3 / 2,
                    endAngle: 0,
                    clockwise: true)
    } else {
        path.addLine(to: CGPoint(x: size.width - halfBorderWidth, y: halfBorderWidth))
    }
    if corner.isSuperset(of: .bottomRight) {
        path.addLine(to: CGPoint(x: size.width - halfBorderWidth, y: size.height - cornerRadius - halfBorderWidth))
        path.addArc(withCenter: CGPoint(x: size.width - cornerRadius - halfBorderWidth, y: size.height - cornerRadius - halfBorderWidth),
                    radius: cornerRadius,
                    startAngle: 0,
                    endAngle: CGFloat.pi / 2,
                    clockwise: true)
    } else {
        path.addLine(to: CGPoint(x: size.width - halfBorderWidth, y: size.height - halfBorderWidth))
    }
    if corner.isSuperset(of: .bottomLeft) {
        path.addLine(to: CGPoint(x: cornerRadius + halfBorderWidth, y: size.height - halfBorderWidth))
        path.addArc(withCenter: CGPoint(x: cornerRadius + halfBorderWidth, y: size.height - cornerRadius - halfBorderWidth),
                    radius: cornerRadius,
                    startAngle: CGFloat.pi / 2,
                    endAngle: CGFloat.pi,
                    clockwise: true)
    } else {
        path.addLine(to: CGPoint(x: halfBorderWidth, y: size.height - halfBorderWidth))
    }
    path.close()
    return path
}

public func bb_drawForScaleDown(_ context: CGContext, sourceImage: CGImage) {
    let sourceImageTileSizeMB = 20
    let pixelsPerMB = 1024 * 1024 * 4
    let tileTotalPixels = sourceImageTileSizeMB * pixelsPerMB
    let imageScale = sqrt(CGFloat(context.width * context.height) / CGFloat(sourceImage.width * sourceImage.height))
    var sourceTile = CGRect(x: 0, y: 0, width: sourceImage.width, height: tileTotalPixels / sourceImage.width)
    var destTile = CGRect(x: 0, y: 0, width: CGFloat(context.width), height: ceil(sourceTile.height * imageScale))
    let destSeemOverlap: CGFloat = 2
    let sourceSeemOverlap = trunc(destSeemOverlap / imageScale)
    var iterations = Int(CGFloat(sourceImage.height) / sourceTile.height)
    let remainder = sourceImage.height % Int(sourceTile.height)
    if remainder != 0 { iterations += 1 }
    let sourceTileHeightMinusOverlap = sourceTile.height
    let destTileHeightMinusOverlap = destTile.height
    sourceTile.size.height += sourceSeemOverlap
    destTile.size.height += destSeemOverlap
    for y in 0..<iterations {
        autoreleasepool {
            sourceTile.origin.y = CGFloat(y) * sourceTileHeightMinusOverlap // + sourceSeemOverlap
            destTile.origin.y = CGFloat(context.height) - ceil(CGFloat(y + 1) * destTileHeightMinusOverlap + destSeemOverlap)
            if let sourceTileImage = sourceImage.cropping(to: sourceTile) {
                if y == iterations - 1 && remainder != 0 {
                    var dify = destTile.height
                    destTile.size.height = ceil(CGFloat(sourceTileImage.height) * imageScale)
                    dify -= destTile.height
                    destTile.origin.y += dify
                }
                context.draw(sourceTileImage, in: destTile)
            }
        }
    }
}

/// BBWebImageEditor defines how to edit and cache image in memory
public struct BBWebImageEditor {
    public var key: String
    public var edit: BBWebImageEditMethod
    
    /// Creates a BBWebImageEditor variable
    ///
    /// - Parameters:
    ///   - key: identification of editor
    ///   - needData: whether image data is necessary or not for editing
    ///   - edit: an edit image closure
    public init(key: String, edit: @escaping BBWebImageEditMethod) {
        self.key = key
        self.edit = edit
    }
}

public extension UIImage {
    /// Creates an image cropped to the specific rect
    ///
    /// - Parameter originalRect: rect to crop, mesured in points
    /// - Returns: a cropped image
    func bb_croppedImage(with originalRect: CGRect) -> UIImage? {
        if originalRect.width <= 0 || originalRect.height <= 0 { return nil }
        var rect = originalRect
        if scale != 1 {
            rect.origin.x *= scale
            rect.origin.y *= scale
            rect.size.width *= scale
            rect.size.height *= scale
        }
        return _bb_croppedImage(with: rect)
    }
    
    /// Creates an image resized to the specific size.
    /// The image will be scaled.
    ///
    /// - Parameter size: size to resize
    /// - Returns: a resized image
    func bb_resizedImage(with size: CGSize) -> UIImage? {
        if size.width <= 0 || size.height <= 0 { return nil }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    /// Creates an image resized with view size and content mode.
    /// Some portion of the image may be clipped.
    /// Use the method to display the valid portion of image to save memory.
    ///
    /// - Parameters:
    ///   - displaySize: view size
    ///   - contentMode: view content mode
    /// - Returns: a resized image
    func bb_resizedImage(with displaySize: CGSize, contentMode: UIView.ContentMode) -> UIImage? {
        if displaySize.width <= 0 || displaySize.height <= 0 { return nil }
        let rect = bb_rectToDisplay(with: displaySize, contentMode: contentMode)
        return _bb_croppedImage(with: rect)
    }
    
    /// Creates an image resized with view size and fill content mode.
    /// Some portion of the image may be clipped.
    /// Use the method to display the valid portion of image to save memory.
    ///
    /// - Parameters:
    ///   - displaySize: view size
    ///   - fillContentMode: fill content mode specifying how content fills its view
    /// - Returns: a resized image
    func bb_resizedImage(with displaySize: CGSize, fillContentMode: UIView.BBFillContentMode) -> UIImage? {
        if displaySize.width <= 0 || displaySize.height <= 0 { return nil }
        let rect = bb_rectToDisplay(with: displaySize, fillContentMode: fillContentMode)
        return _bb_croppedImage(with: rect)
    }
    
    private func _bb_croppedImage(with rect: CGRect) -> UIImage? {
        if let sourceImage = cgImage?.cropping(to: rect) {
            return UIImage(cgImage: sourceImage, scale: scale, orientation: imageOrientation)
        }
        if let ciimage = ciImage?.cropped(to: rect),
            let sourceImage = bb_shareCIContext.createCGImage(ciimage, from: ciimage.extent) {
            return UIImage(cgImage: sourceImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
    
    /// Creates an image rotated with given angle
    ///
    /// - Parameters:
    ///   - angle: angle (degree) to rotate
    ///   - fitSize: true to change image size to fit rotated image, false to keep image size
    /// - Returns: a rotated image
    func bb_rotatedImage(withAngle angle: CGFloat, fitSize: Bool) -> UIImage? {
        if angle.truncatingRemainder(dividingBy: 360) == 0 { return self }
        let radian = angle / 180 * CGFloat.pi
        var rect = CGRect(origin: .zero, size: size)
        if fitSize { rect = rect.applying(CGAffineTransform(rotationAngle: radian)) }
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        context.translateBy(x: rect.width / 2, y: rect.height / 2)
        context.rotate(by: radian)
        context.translateBy(x: -size.width / 2, y: -size.height / 2)
        draw(at: .zero)
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
    
    /// Creates an image flipped horizontally and/or vertically
    ///
    /// - Parameters:
    ///   - horizontal: whether to flip horizontally or not
    ///   - vertical: whether to flip vertically or not
    /// - Returns: a flipped image
    func bb_flippedImage(withHorizontal horizontal: Bool, vertical: Bool) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        if horizontal {
            context.translateBy(x: size.width, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        if vertical {
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
        }
        draw(at: .zero)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    /// Creates an image tinted with color
    ///
    /// - Parameters:
    ///   - color: color to draw
    ///   - blendMode: blend mode to use when compositing the image
    /// - Returns: a tinted image
    func bb_tintedImage(with color: UIColor, blendMode: CGBlendMode = .normal) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: .zero)
        color.setFill()
        UIRectFillUsingBlendMode(CGRect(origin: .zero, size: size), blendMode)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    /// Creates an image tinted with gradient color
    ///
    /// - Parameters:
    ///   - colors: colors to draw
    ///   - locations: location of each color provided in colors. Each location must be a CGFloat value in the range of 0 to 1
    ///   - start: starting point (x and y are in the range of 0 to 1) of the gradient
    ///   - end: ending point (x and y are in the range of 0 to 1) of the gradient
    ///   - blendMode: blend mode to use when compositing the image
    /// - Returns: a gradiently tinted image
    func bb_gradientlyTintedImage(with colors: [UIColor],
                                         locations: [CGFloat],
                                         start: CGPoint = CGPoint(x: 0.5, y: 0),
                                         end: CGPoint = CGPoint(x: 0.5, y: 1),
                                         blendMode: CGBlendMode = .normal) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext(),
            let gradient = CGGradient(colorsSpace: bb_shareColorSpace,
                                      colors: colors.map { $0.cgColor } as CFArray,
                                      locations: locations) else
        {
            UIGraphicsEndImageContext()
            return nil
        }
        context.setBlendMode(blendMode)
        let startLoc = CGPoint(x: start.x * size.width, y: start.y * size.height)
        let endLoc = CGPoint(x: end.x * size.width, y: end.y * size.height)
        context.drawLinearGradient(gradient,
                                   start: startLoc,
                                   end: endLoc,
                                   options: CGGradientDrawingOptions(rawValue: 0))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    /// Creates an image overlaid by another image
    ///
    /// - Parameters:
    ///   - overlayImage: image at the top as an overlay
    ///   - blendMode: blend mode to use when compositing the image
    ///   - alpha: opacity of overlay image, specified as a value between 0 (totally transparent) and 1 (fully opaque)
    /// - Returns: an overlaid image
    func bb_overlaidImage(with overlayImage: UIImage, blendMode: CGBlendMode = .normal, alpha: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: .zero)
        overlayImage.draw(in: CGRect(origin: .zero, size: size), blendMode: blendMode, alpha: alpha)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    /// Creates an image for common use
    ///
    /// - Parameters:
    ///   - displaySize: size of view displaying image
    ///   - fillContentMode: fill content mode specifying how content fills its view
    ///   - maxResolution: an expected maximum resolution of decoded image
    ///   - corner: how many image corners are drawn
    ///   - cornerRadius: corner radius of image, in view's coordinate
    ///   - borderWidth: border width of image, in view's coordinate
    ///   - borderColor: border color of image
    ///   - backgroundColor: background color of image
    /// - Returns: a BBWebImageEditor variable
    func bb_commonEditedImage(with displaySize: CGSize,
                                     fillContentMode: UIView.BBFillContentMode = .center,
                                     maxResolution: Int = 0,
                                     corner: UIRectCorner = UIRectCorner(rawValue: 0),
                                     cornerRadius: CGFloat = 0,
                                     borderWidth: CGFloat = 0,
                                     borderColor: UIColor? = nil,
                                     backgroundColor: UIColor? = nil) -> UIImage? {
        return autoreleasepool { () -> UIImage? in
            guard displaySize.width > 0,
                displaySize.height > 0,
                let sourceImage = cgImage?.cropping(to: bb_rectToDisplay(with: displaySize, fillContentMode: fillContentMode)) else { return nil }
            var bitmapInfo = sourceImage.bitmapInfo
            bitmapInfo.remove(.alphaInfoMask)
            if sourceImage.bb_containsAlpha {
                bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            } else {
                bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
            }
            // Make sure resolution is not too small
            let currentMaxResolution = max(maxResolution, Int(displaySize.width * displaySize.height * 7))
            let resolutionRatio = sqrt(CGFloat(sourceImage.width * sourceImage.height) / CGFloat(currentMaxResolution))
            let shouldScaleDown = maxResolution > 0 && resolutionRatio > 1
            var width = sourceImage.width
            var height = sourceImage.height
            if shouldScaleDown {
                width = Int(CGFloat(sourceImage.width) / resolutionRatio)
                height = Int(CGFloat(sourceImage.height) / resolutionRatio)
            } else if CGFloat(width) < displaySize.width * bb_ScreenScale {
                width = Int(displaySize.width * bb_ScreenScale)
                height = Int(displaySize.height * bb_ScreenScale)
            }
            guard let context = CGContext(data: nil,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: sourceImage.bitsPerComponent,
                                          bytesPerRow: 0,
                                          space: bb_shareColorSpace,
                                          bitmapInfo: bitmapInfo.rawValue) else { return nil }
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: CGFloat(-height))
            context.interpolationQuality = .high
            context.saveGState()
            
            let ratio = CGFloat(width) / displaySize.width
            let currentCornerRadius = cornerRadius * ratio
            let currentBorderWidth = borderWidth * ratio
            
            if let fillColor = backgroundColor?.cgColor {
                context.setFillColor(fillColor)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            if cornerRadius > 0 && corner.isSubset(of: .allCorners) && !corner.isEmpty {
                let clipPath = bb_borderPath(with: CGSize(width: width, height: height), corner: corner, cornerRadius: currentCornerRadius, borderWidth: currentBorderWidth)
                context.addPath(clipPath.cgPath)
                context.clip()
            }
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: CGFloat(-height))
            if shouldScaleDown {
                bb_drawForScaleDown(context, sourceImage: sourceImage)
            } else {
                context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            context.restoreGState()
            if let strokeColor = borderColor?.cgColor,
                borderWidth > 0 {
                let strokePath = bb_borderPath(with: CGSize(width: width, height: height), corner: corner, cornerRadius: currentCornerRadius, borderWidth: currentBorderWidth)
                context.addPath(strokePath.cgPath)
                context.setLineWidth(currentBorderWidth)
                context.setStrokeColor(strokeColor)
                context.strokePath()
            }
            return context.makeImage().flatMap { UIImage(cgImage: $0) }
        }
    }
    
    /// Calculates image rect to display with view size and content mode.
    /// Use the rect to crop image to fit view size and content mode.
    ///
    /// - Parameters:
    ///   - displaySize: view size
    ///   - contentMode: view content mode
    /// - Returns: image rect to display in image coordinate
    func bb_rectToDisplay(with displaySize: CGSize, contentMode: UIView.ContentMode) -> CGRect {
        var rect = CGRect(origin: .zero, size: size)
        switch contentMode {
        case .scaleAspectFill:
            let sourceRatio = size.width / size.height
            let displayRatio = displaySize.width / displaySize.height
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
                rect.origin.y = (size.height - rect.height) / 2
            } else {
                rect.size.width = size.height * displayRatio
                rect.origin.x = (size.width - rect.width) / 2
            }
        case .center:
            if size.width > displaySize.width {
                rect.origin.x = (size.width - displaySize.width) / 2
                rect.size.width = displaySize.width
            }
            if size.height > displaySize.height {
                rect.origin.y = (size.height - displaySize.height) / 2
                rect.size.height = displaySize.height
            }
        case .top:
            if size.width > displaySize.width {
                rect.origin.x = (size.width - displaySize.width) / 2
                rect.size.width = displaySize.width
            }
            if size.height > displaySize.height {
                rect.size.height = displaySize.height
            }
        case .bottom:
            if size.width > displaySize.width {
                rect.origin.x = (size.width - displaySize.width) / 2
                rect.size.width = displaySize.width
            }
            if size.height > displaySize.height {
                rect.origin.y = size.height - displaySize.height
                rect.size.height = displaySize.height
            }
        case .left:
            if size.height > displaySize.height {
                rect.origin.y = (size.height - displaySize.height) / 2
                rect.size.height = displaySize.height
            }
            if size.width > displaySize.width {
                rect.size.width = displaySize.width
            }
        case .right:
            if size.height > displaySize.height {
                rect.origin.y = (size.height - displaySize.height) / 2
                rect.size.height = displaySize.height
            }
            if size.width > displaySize.width {
                rect.origin.x = size.width - displaySize.width
                rect.size.width = displaySize.width
            }
        case .topLeft:
            if size.width > displaySize.width {
                rect.size.width = displaySize.width
            }
            if size.height > displaySize.height {
                rect.size.height = displaySize.height
            }
        case .topRight:
            if size.width > displaySize.width {
                rect.origin.x = size.width - displaySize.width
                rect.size.width = displaySize.width
            }
            if size.height > displaySize.height {
                rect.size.height = displaySize.height
            }
        case .bottomLeft:
            if size.width > displaySize.width {
                rect.size.width = displaySize.width
            }
            if size.height > displaySize.height {
                rect.origin.y = size.height - displaySize.height
                rect.size.height = displaySize.height
            }
        case .bottomRight:
            if size.width > displaySize.width {
                rect.origin.x = size.width - displaySize.width
                rect.size.width = displaySize.width
            }
            if size.height > displaySize.height {
                rect.origin.y = size.height - displaySize.height
                rect.size.height = displaySize.height
            }
        default:
            break
        }
        if scale != 1 {
            rect.origin.x *= scale
            rect.origin.y *= scale
            rect.size.width *= scale
            rect.size.height *= scale
        }
        return rect
    }
    
    /// Calculates image rect to display with view size and fill content mode.
    /// Use the rect to crop image to fit view size and fill content mode.
    ///
    /// - Parameters:
    ///   - displaySize: view size
    ///   - fillContentMode: fill content mode specifying how content fills its view
    /// - Returns: image rect to display in image coordinate
    func bb_rectToDisplay(with displaySize: CGSize, fillContentMode: UIView.BBFillContentMode) -> CGRect {
        var rect = CGRect(origin: .zero, size: size)
        let sourceRatio = size.width / size.height
        let displayRatio = displaySize.width / displaySize.height
        switch fillContentMode {
        case .center:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
                rect.origin.y = (size.height - rect.height) / 2
            } else {
                rect.size.width = size.height * displayRatio
                rect.origin.x = (size.width - rect.width) / 2
            }
        case .top:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
            } else {
                rect.size.width = size.height * displayRatio
                rect.origin.x = (size.width - rect.width) / 2
            }
        case .bottom:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
                rect.origin.y = size.height - rect.height
            } else {
                rect.size.width = size.height * displayRatio
                rect.origin.x = (size.width - rect.width) / 2
            }
        case .left:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
                rect.origin.y = (size.height - rect.height) / 2
            } else {
                rect.size.width = size.height * displayRatio
            }
        case .right:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
                rect.origin.y = (size.height - rect.height) / 2
            } else {
                rect.size.width = size.height * displayRatio
                rect.origin.x = size.width - rect.width
            }
        case .topLeft:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
            } else {
                rect.size.width = size.height * displayRatio
            }
        case .topRight:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
            } else {
                rect.size.width = size.height * displayRatio
                rect.origin.x = size.width - rect.width
            }
        case .bottomLeft:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
                rect.origin.y = size.height - rect.height
            } else {
                rect.size.width = size.height * displayRatio
            }
        case .bottomRight:
            if sourceRatio < displayRatio {
                rect.size.height = size.width / displayRatio
                rect.origin.y = size.height - rect.height
            } else {
                rect.size.width = size.height * displayRatio
                rect.origin.x = size.width - rect.width
            }
        }
        if scale != 1 {
            rect.origin.x *= scale
            rect.origin.y *= scale
            rect.size.width *= scale
            rect.size.height *= scale
        }
        return rect
    }
}

public extension UIView {
    /// BBFillContentMode specifies how content fills its view
    enum BBFillContentMode {
        /// Aligns center and aspect fill
        case center
        
        /// Aligns top and aspect fill
        case top
        
        /// Aligns bottom and aspect fill
        case bottom
        
        /// Aligns left and aspect fill
        case left
        
        /// Aligns right and aspect fill
        case right
        
        /// Aligns top left and aspect fill
        case topLeft
        
        /// Aligns top right and aspect fill
        case topRight
        
        /// Aligns bottom left and aspect fill
        case bottomLeft
        
        /// Aligns bottom right and aspect fill
        case bottomRight
    }
}
