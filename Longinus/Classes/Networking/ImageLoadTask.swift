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
        lock.locked { [weak self]() -> (Bool) in
            return self?.cancelled ?? false
        }
    }
    public let sentinel: Int32
    public var downloadTask: ImageDownloadTaskable?
    public weak var imageManager: LonginusManager?
    private var cancelled: Bool
    private var lock: Mutex
    
    init(sentinel: Int32) {
        self.sentinel = sentinel
        cancelled = false
        lock = Mutex()
    }
    
    /// Cancels current image loading task
    public func cancel() {
        lock.locked { [weak self] in
            guard let self = self else { return }
            if cancelled {
                return
            }
        }
        cancelled = true
        lock.unlock()
        
        if let task = downloadTask,
            let downloader = imageManager?.imageDownloader {
            downloader.cancel(task: task)
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
