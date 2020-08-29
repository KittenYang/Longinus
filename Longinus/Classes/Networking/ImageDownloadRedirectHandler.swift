//
//  ImageDownloadRedirectHandler.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/8/30.
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

/// Represents and wraps a method for modifying request during an image download request redirection.
public protocol ImageDownloadRedirectHandler {

    /// The `ImageDownloadRedirectHandler` contained will be used to change the request before redirection.
    /// This is the posibility you can modify the image download request during redirection. You can modify the
    /// request for some customizing purpose, such as adding auth token to the header, do basic HTTP auth or
    /// something like url mapping.
    ///
    /// Usually, you pass an `ImageDownloadRedirectHandler` as the associated value of
    /// `LonginusImageOptionItem.redirectHandler` and use it as the `options` parameter in related methods.
    ///
    /// If you do nothing with the input `request` and return it as is, a downloading process will redirect with it.
    ///
    /// - Parameters:
    ///   - operation: The current `ImageDownloadOperation` which triggers this redirect.
    ///   - response: The response received during redirection.
    ///   - newRequest: The request for redirection which can be modified.
    ///   - completionHandler: A closure for being called with modified request.
    func handleHTTPRedirection(
        for operation: ImageDownloadOperation,
        response: HTTPURLResponse,
        newRequest: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void)
}

/// A wrapper for creating an `ImageDownloadRedirectHandler` easier.
/// This type conforms to `ImageDownloadRedirectHandler` and wraps a redirect request modify block.
public struct AnyRedirectHandler: ImageDownloadRedirectHandler {
    
    let block: (ImageDownloadOperation, HTTPURLResponse, URLRequest, (URLRequest?) -> Void) -> Void

    public func handleHTTPRedirection(
        for operation: ImageDownloadOperation,
        response: HTTPURLResponse,
        newRequest: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void) {
        block(operation, response, newRequest, completionHandler)
    }
    
    /// Creates a value of `ImageDownloadRedirectHandler` which runs `modify` block.
    public init(handle: @escaping (ImageDownloadOperation, HTTPURLResponse, URLRequest, (URLRequest?) -> Void) -> Void) {
        block = handle
    }
}
