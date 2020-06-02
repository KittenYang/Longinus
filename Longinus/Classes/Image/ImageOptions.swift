//
//  ImageOptions.swift
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

public struct ImageOptions: OptionSet {
    public let rawValue: Int
    
    /// Default behavior
    public static let none = ImageOptions([])
    
    /// Query image data when memory image is gotten
    public static let queryDataWhenInMemory = ImageOptions(rawValue: 1 << 0)
    
    /// Do not use image disk cache
    public static let ignoreDiskCache = ImageOptions(rawValue: 1 << 1)
    
    /// Download image and update cache
    public static let refreshCache = ImageOptions(rawValue: 1 << 2)
    
    /// Retry to download even the url is blacklisted for failed downloading
    public static let retryFailedUrl = ImageOptions(rawValue: 1 << 3)
    
    /// URLRequest.cachePolicy = .useProtocolCachePolicy
    public static let useURLCache = ImageOptions(rawValue: 1 << 4)
    
    /// URLRequest.httpShouldHandleCookies = true
    public static let handleCookies = ImageOptions(rawValue: 1 << 5)
    
    /// Image is displayed progressively when downloading
    public static let progressiveDownload = ImageOptions(rawValue: 1 << 6)
    
    /// Do not display placeholder image
    public static let ignorePlaceholder = ImageOptions(rawValue: 1 << 7)
    
    /// Do not decode image
    public static let ignoreImageDecoding = ImageOptions(rawValue: 1 << 8)
    
    /// Set the image to view with a fade animation.
    public static let imageWithFadeAnimation = ImageOptions(rawValue: 1 << 9)
    
    /// Preload image data and cache to disk
    internal static let preload = ImageOptions(rawValue: 1 << 32)
    
    public init(rawValue: Int) { self.rawValue = rawValue }
}
