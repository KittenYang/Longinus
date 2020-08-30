//
//  LonginusImageOptions.swift
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

/// LonginusOptionsInfo is a typealias for [LonginusImageOptionItem].
/// You can use the enum of option item with value to control some behaviors of Longinus.
public typealias LonginusImageOptions = [LonginusImageOptionItem]

extension Array where Element == LonginusImageOptionItem {
    static let empty: LonginusImageOptions = []
}

/// Represents the available option items could be used in `LonginusImageOptions`.
public enum LonginusImageOptionItem {
    
    /// Query image data when memory image is gotten
    case queryDataWhenInMemory
    
    /// Do not use image disk cache
    case ignoreDiskCache
    
    /// Download image and update cache
    case refreshCache
    
    /// Retry to download even the url is blacklisted for failed downloading
    case retryFailedUrl
    
    /// URLRequest.cachePolicy = .useProtocolCachePolicy
    case useURLCache
    
    /// URLRequest.httpShouldHandleCookies = true
    case handleCookies
    
    /// The `ImageDownloadRequestModifier` contained will be used to change the request before it being sent.
    /// This is the last chance you can modify the image download request. You can modify the request for some
    /// customizing purpose, such as adding auth token to the header, do basic HTTP auth or something like url mapping.
    /// The original request will be sent without any modification by default.
    case requestModifier(URLRequestModifier)
    
    /// A convenient option for only modifying http headers
    case httpHeadersModifier(URLHttpHeadersModifier)
    
    /// The `ImageDownloadRedirectHandler` contained will be used to change the request before redirection.
    /// This is the possibility you can modify the image download request during redirect. You can modify the request for
    /// some customizing purpose, such as adding auth token to the header, do basic HTTP auth or something like url
    /// mapping.
    /// The original redirection request will be sent without any modification by default.
    case redirectHandler(ImageDownloadRedirectHandler)
    
    /// Display progressive/interlaced/baseline image during download (same as web browser).
    /// Image is displayed progressively when downloading
    case progressiveDownload
    
    /// Display blurred progressive JPEG or interlaced PNG image during download.
    /// This will ignore baseline image for better user experience.
    case progressiveBlur
    
    /// Do not display placeholder image
    case ignorePlaceholder
    
    /// Do not decode image
    /// This may used for image downloading without display.
    case ignoreImageDecoding
    
    /// Set the image to view with a fade animation.
    case imageWithFadeAnimation
    
    /// Whether show activity indicator on status bar when downloading image
    case showNetworkActivity
    
    /// Ignore multi-frame image decoding.
    /// This will handle the GIF image as single frame image.
    case ignoreAnimatedImage
    
    /// Note: **DO NOT** use this case by yourself. If you wanna preload image, please use `preload` method in `LonginusManager.swift`
    case preload
    
}

// Improve performance by parsing the input `LonginusImageOptions` (self) first.
// So we can prevent the iterating over the options array again and again.
/// The parsed options info used across Longinus methods. Each property in this type corresponds a case member
/// in `LonginusImageOptionItem`. When a `LonginusImageOptions` sent to Longinus related methods, it will be
/// parsed and converted to a `LonginusParsedImageOptionsInfo` first, and pass through the internal methods.
public struct LonginusParsedImageOptionsInfo {

    public var queryDataWhenInMemory: Bool = false
    public var ignoreDiskCache: Bool = false
    public var refreshCache: Bool = false
    public var retryFailedUrl: Bool = false
    public var useURLCache: Bool = false
    public var handleCookies: Bool = false
    public var progressiveDownload: Bool = false
    public var ignorePlaceholder: Bool = false
    public var ignoreImageDecoding: Bool = false
    public var imageWithFadeAnimation: Bool = false
    public var showNetworkActivity: Bool = false
    public var progressiveBlur: Bool = false
    public var ignoreAnimatedImage: Bool = false
    internal var preload: Bool = false
    public var requestModifier: URLRequestModifier? = nil
    public var httpHeadersModifier: URLHttpHeadersModifier? = nil
    public var redirectHandler: ImageDownloadRedirectHandler? = nil
    
    public init(_ options: LonginusImageOptions?) {
        guard let options = options else { return }
        for option in options {
            switch option {
            case .queryDataWhenInMemory: queryDataWhenInMemory = true
            case .ignoreDiskCache: ignoreDiskCache = true
            case .refreshCache: refreshCache = true
            case .retryFailedUrl: retryFailedUrl = true
            case .useURLCache: useURLCache = true
            case .handleCookies: handleCookies = true
            case .progressiveDownload: progressiveDownload = true
            case .ignorePlaceholder: ignorePlaceholder = true
            case .ignoreImageDecoding: ignoreImageDecoding = true
            case .imageWithFadeAnimation: imageWithFadeAnimation = true
            case .showNetworkActivity: showNetworkActivity = true
            case .progressiveBlur: progressiveBlur = true
            case .ignoreAnimatedImage: ignoreAnimatedImage = true
            case .preload: preload = true
            case .requestModifier(let value): requestModifier = value
            case .httpHeadersModifier(let value): httpHeadersModifier = value
            case .redirectHandler(let value): redirectHandler = value
            }
        }
    }
    
}
