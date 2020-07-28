//
//  ImageLoadTask.swift
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

/// ImageLoadTask defines an image loading task
public class ImageLoadTask: NSObject { // If not subclass NSObject, there is memory leak (unknown reason)
    public var isCancelled: Bool {
        lock.lock()
        let cancel = self.cancelled
        lock.unlock()
        return cancel
    }
    public let url: URL
    public let sentinel: Int32
    public var downloadInfo: ImageDownloadInfo?
    public weak var imageManager: LonginusManager?
    private var cancelled: Bool
    private var lock: Mutex
    
    init(sentinel: Int32, url: URL) {
        self.sentinel = sentinel
        self.url = url
        cancelled = false
        lock = Mutex()
    }
    
    /// Cancels current image loading task
    public func cancel() {
        lock.lock()
        if self.cancelled {
            lock.unlock()
            return
        }
        cancelled = true
        lock.unlock()
        
        if let info = downloadInfo,
            let downloader = imageManager?.imageDownloader {
            downloader.cancel(info: info)
        }
        imageManager?.remove(loadTask: self)
    }
    
    public static func == (lhs: ImageLoadTask, rhs: ImageLoadTask) -> Bool {
        return lhs.sentinel == rhs.sentinel
    }
    
    public override var hash: Int {
        return Int(sentinel)
    }
}
