//
//  ImageDownloadRequestModifier.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/8/29.
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

/// Represents and wraps a method for modifying request before an image download request starts.
public protocol ImageDownloadModifier {

    associatedtype T
    /// A method will be called just before the `request` being sent.
    /// This is the last chance you can modify the image download request. You can modify the request for some
    /// customizing purpose, such as adding auth token to the header, do basic HTTP auth or something like url mapping.
    ///
    /// Usually, you pass an `ImageDownloadRequestModifier` as the associated value of
    /// `LonginusImageOptionItem.requestModifier` and use it as the `options` parameter in related methods.
    ///
    /// If you do nothing with the input `request` and return it as is, a downloading process will start with it.
    ///
    /// - Parameter request: The input request contains necessary information like `url`. This request is generated
    ///                      according to your resource url as a GET request.
    /// - Returns: A modified version of request, which you wish to use for downloading an image.
    ///                     If `nil` returned, a `LonginusImageErrorDomain` error with `empty request` message as its
    ///                     reason will occur.
    ///
    func modified(for original: T?) -> T?
}


/// A wrapper for creating an `ImageDownloadRequestModifier` easier.
/// This type conforms to `ImageDownloadRequestModifier` and wraps an image modify block.
public struct URLRequestModifier: ImageDownloadModifier {
    
    let block: (URLRequest?) -> URLRequest?

    /// For `ImageDownloadRequestModifier` conformation.
    public func modified(for request: URLRequest?) -> URLRequest? {
        return block(request)
    }
    
    /// Creates a value of `ImageDownloadRequestModifier` which runs `modify` block.
    ///
    /// - Parameter modify: The request modifying block runs when a request modifying task comes.
    ///                     The return `URLRequest?` value of this block will be used as the image download request.
    ///                     If `nil` returned, a `LonginusImageErrorDomain` error with `empty request` message as its
    ///                     reason will occur.
    public init(modify: @escaping (URLRequest?) -> URLRequest?) {
        block = modify
    }
}

/// A modifier to modify URL
public struct URLModifier: ImageDownloadModifier {
    var url: URL? = nil
    public func modified(for URL: URL?) -> URL? {
        return url
    }
}

/// A modifier to modify httpHeaders
public struct URLHttpHeadersModifier: ImageDownloadModifier {
    var httpHeaders: [String : String]? = nil
    public func modified(for headers: [String : String]?) -> [String : String]? {
        return httpHeaders
    }
}
