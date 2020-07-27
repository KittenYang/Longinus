//
//  LonginusCompatible.swift
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

public let LonginusPrefixID = "com.kittenyang.Longinus"
public let lg_shareColorSpace = CGColorSpaceCreateDeviceRGB()
public let lg_ScreenScale = UIScreen.main.scale

public protocol LonginusCompatible { }


/**
 Wrapper for Longinus compatible types. This type provides an extension point for connivence methods in Longinus.
 */
public struct LonginusExtension<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

/**
 Represents an object type that is compatible with Longinus. You can use `lg` property to get a value in the namespace of Longinus.
 */
extension LonginusCompatible {
    public var lg: LonginusExtension<Self> {
        get { return LonginusExtension(self) }
        set { }
    }
}

extension UIImage: LonginusCompatible {}
extension UIView: LonginusCompatible {}
extension CGImage: LonginusCompatible {}
extension CALayer: LonginusCompatible {}
extension String: LonginusCompatible {}
extension Data: LonginusCompatible {}
extension UIImage.Orientation: LonginusCompatible {}
extension CGImagePropertyOrientation: LonginusCompatible {}
