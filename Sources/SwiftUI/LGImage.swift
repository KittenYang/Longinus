//
//  LGImage.swift
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
import Longinus

@available(iOS 13.0, *)
public struct LGImage: SwiftUI.View {

    /// An image binder that manages loading and cancelling image related task.
    @ObservedObject public private(set) var binder: ImageBinder

    // Acts as a placeholder when loading an image.
    var placeholder: AnyView?

    // Whether the download task should be cancelled when the view disappears.
    var cancelOnDisappear: Bool = false

    // Configurations should be performed on the image.
    var configurations: [(SwiftUI.Image) -> SwiftUI.Image]

    /// Creates a Longinus compatible image view to load image from the given `ImageWebCacheResourceable`.
    /// - Parameter source: The image `ImageWebCacheResourceable` defining where to load the target image.
    /// - Parameter options: The options should be applied when loading the image.
    ///      Some UIKit related options (such as `.imageWithFadeAnimation`) are not supported.
    /// - Parameter isLoaded: Whether the image is loaded or not. This provides a way to inspect the internal loading state.
    /// `true` if the image is loaded successfully. Otherwise, `false`.
    /// Do not set the wrapped value from outside.
    public init<Content: SwiftUI.View>(source: ImageWebCacheResourceable?, @ViewBuilder placeholder builder: (() -> Content), options: LonginusImageOptions? = nil, transformer: ImageTransformer? = nil, isLoaded: Binding<Bool> = .constant(false)) {
        binder = ImageBinder(source: source, options: options, transformer: transformer, isLoaded: isLoaded)
        configurations = []
        self.placeholder = AnyView(builder())
        binder.start()
    }


    /// Declares the content and behavior of this view.
    public var body: some SwiftUI.View {
        Group {
            if binder.image != nil {
                configurations
                    .reduce(SwiftUI.Image(uiImage: binder.image!)) {
                        current, config in config(current)
                    }
            } else {
                Group {
                    if placeholder != nil {
                        placeholder
                    } else {
                        SwiftUI.Image(.init())
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .onDisappear { [weak binder = self.binder] in
                    if self.cancelOnDisappear {
                        binder?.cancel()
                    }
                }
            }
        }.onAppear { [weak binder] in
            guard let binder = binder else {
                return
            }
            if !binder.loadingOrSuccessed {
                binder.start()
            }
        }
    }
}

@available(iOS 13.0, *)
extension LGImage {

    /// Configures current image with a `block`. This block will be lazily applied when creating the final `Image`.
    /// - Parameter block: The block applies to loaded image.
    /// - Returns: A `LGImage` view that configures internal `Image` with `block`.
    public func configure(_ block: @escaping (SwiftUI.Image) -> SwiftUI.Image) -> LGImage {
        var result = self
        result.configurations.append(block)
        return result
    }

    public func resizable(
        capInsets: EdgeInsets = EdgeInsets(),
        resizingMode: SwiftUI.Image.ResizingMode = .stretch) -> LGImage
    {
        configure { $0.resizable(capInsets: capInsets, resizingMode: resizingMode) }
    }

    public func renderingMode(_ renderingMode: SwiftUI.Image.TemplateRenderingMode?) -> LGImage {
        configure { $0.renderingMode(renderingMode) }
    }

    public func interpolation(_ interpolation: SwiftUI.Image.Interpolation) -> LGImage {
        configure { $0.interpolation(interpolation) }
    }

    public func antialiased(_ isAntialiased: Bool) -> LGImage {
        configure { $0.antialiased(isAntialiased) }
    }

    /// Sets cancelling the download task bound to `self` when the view disappearing.
    /// - Parameter flag: Whether cancel the task or not.
    /// - Returns: A `LGImage` view that cancels downloading task when disappears.
    public func cancelOnDisappear(_ flag: Bool) -> LGImage {
        var result = self
        result.cancelOnDisappear = flag
        return result
    }
}

@available(iOS 13.0, *)
extension LGImage {

    /// Sets the completion block when the image setting finished.
    /// - Parameter block: The block to perform.
    /// - Returns: A `LGImage` view that triggers `action` when setting image finished.
    public func onCompletion(completion block: @escaping ImageManagerCompletionBlock) -> LGImage {
        binder.setonCompletion(completion: block)
        return self
    }

    /// Sets the action to perform when the image downloading progress receiving new data.
    /// - Parameter block: The block to perform. If `action` is `nil`, the
    ///   call has no effect.
    /// - Returns: A `LGImage` view that triggers `action` when new data arrives when downloading.
    public func onProgress(progress block: ImageDownloaderProgressBlock?) -> LGImage {
        binder.setOnProgress(progress: block)
        return self
    }
}

#endif
