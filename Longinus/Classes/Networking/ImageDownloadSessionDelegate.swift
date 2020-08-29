//
//  ImageDownloadSessionDelegate.swift
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

// Represents the delegate object of downloader session. It also behave like a task manager for downloading.
class ImageDownloadSessionDelegate: NSObject {
    
    private weak var downloader: ImageDownloader?
    
    init(downloader: ImageDownloader) {
        self.downloader = downloader
    }
    
}

extension ImageDownloadSessionDelegate: URLSessionDataDelegate {

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let url = task.originalRequest?.url,
            let operation = downloader?.operation(for: url),
            operation.dataTaskId == task.taskIdentifier,
            let taskDelegate = operation as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, task: task, didCompleteWithError: error)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let url = dataTask.originalRequest?.url,
            let operation = downloader?.operation(for: url),
            operation.dataTaskId == dataTask.taskIdentifier,
            let dataDelegate = operation as? URLSessionDataDelegate {
            dataDelegate.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
        } else {
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        if let url = dataTask.originalRequest?.url,
            let operation = downloader?.operation(for: url),
            operation.dataTaskId == dataTask.taskIdentifier,
            let dataDelegate = operation as? URLSessionDataDelegate {
            dataDelegate.urlSession?(session, dataTask: dataTask, didReceive: data)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let downloader = self.downloader else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        self.downloader?.authenticationChallengeResponder?.downloader(downloader, didReceive: challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let downloader = self.downloader else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        self.downloader?.authenticationChallengeResponder?.downloader(downloader, task: task, didReceive: challenge, completionHandler: completionHandler)
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void) {
    
        guard let url = task.originalRequest?.url,
            let operation = downloader?.operation(for: url) as? ImageDownloadOperation,
            let options = operation.options,
            let redirectHandler = LonginusParsedImageOptionsInfo(options).redirectHandler else {
            completionHandler(request)
            return
        }
        
        redirectHandler.handleHTTPRedirection(
            for: operation,
            response: response,
            newRequest: request,
            completionHandler: completionHandler)
    }

    
}

