//
//  ImageBinder.swift
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
    

#if canImport(SwiftUI) && canImport(Combine)
import Combine
import SwiftUI

@available(iOS 13.0, *)
extension LGImage {

    /// Represents a binder for `LGImage`. It takes responsibility as an `ObjectBinding` and performs
    /// image downloading and progress reporting based on `LonginusManager`.
    public class ImageBinder: ObservableObject {

        let source: ImageWebCacheResourceable?
        let options: LonginusImageOptions?
        let transformer: ImageTransformer?
        var loadTask: ImageLoadTask?

        var loadingOrSuccessed: Bool = false

        var onCompletionBlock: ImageManagerCompletionBlock = { (_, _, _, _) in}
        var onProgressBlock: ImageDownloaderProgressBlock?

        var isLoaded: Binding<Bool>

        @Published var image: UIImage?

        init(source: ImageWebCacheResourceable?, options: LonginusImageOptions?, transformer: ImageTransformer?, isLoaded: Binding<Bool>) {
            self.source = source
            self.options = options
            self.transformer = transformer
            self.isLoaded = isLoaded
            self.image = nil
        }

        func start() {

            guard !loadingOrSuccessed else { return }

            loadingOrSuccessed = true

            guard let source = source else {
                DispatchQueue.main.async {
                    self.onCompletionBlock(nil, nil, NSError(domain: LonginusImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "empty source"]), .none)
                }
                return
            }
            
            loadTask = LonginusManager.shared
                .loadImage(with: source,
                           options: options,
                           transformer: self.transformer,
                           progress: { (data, expectedSize, image) in
                            self.onProgressBlock?(data, expectedSize, image)
                },
                           completion: { [weak self] (image, data, error, cacheType) in
                            guard let self = self else { return }
                            self.loadTask = nil
                            if let error = error, image == nil {
                                self.loadingOrSuccessed = false
                                DispatchQueue.main.async {
                                    self.onCompletionBlock(image, data, error, cacheType)
                                }
                                return
                            }
                            if let image = image {
                                self.image = image
                                DispatchQueue.main.async {
                                    self.isLoaded.wrappedValue = true
                                    self.onCompletionBlock(image, data, error, cacheType)
                                }
                            }
                })
        }

        /// Cancels the download task if it is in progress.
        public func cancel() {
            loadTask?.cancel()
        }
        func setonCompletion(completion block: @escaping ImageManagerCompletionBlock) {
            self.onCompletionBlock = block
        }


        func setOnProgress(progress block: ImageDownloaderProgressBlock?) {
            self.onProgressBlock = block
        }
    }
}

#endif
