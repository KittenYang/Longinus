# BBWebImage

A high performance Swift library for downloading, caching and editing web images asynchronously.

[中文介绍](https://www.cnblogs.com/silence-cnblogs/p/10442984.html)

## Examples

Simplely download, display and cache images.

![](README_resources/original_image.gif)

Download images. Decode, edit and display images while downloading. After downloading, cache edited images to memory and cache original image data to disk.

- Add filter

![](README_resources/edit_filter.gif)

- Draw rounded corner and border

![](README_resources/edit_common.gif)

## Performance

Test libraries are BBWebImage (1.1.0), SDWebImage (4.4.6 and FLAnimatedImage 1.0.12 for GIF), YYWebImage (1.0.5) and Kingfisher (4.10.1). Test device is iPhone 7 with iOS 12.1. The code can be found in [CompareImageLib](CompareImageLib) project and the test result data can be found in [CompareImageLib.numbers](README_resources/CompareImageLib.numbers).

- BBWebImage has high speed memory and disk cache, especially for thumbnail image.

![](README_resources/compare_memoryCache.png)

![](README_resources/compare_diskCache.png)

- BBWebImage consumes low CPU and memory when loading and displaying GIF.

![](README_resources/compare_gif_CPU_memory.png)

## Features

- [x] View extensions for `UIImageView`, `UIButton`, `MKAnnotationView` and `CALayer` to set image from URL
- [x] Asynchronous image downloader
- [x] Asynchronous memory + file + SQLite image cache with least recently used algorithm
- [x] Asynchronous image decompressing
- [x] Asynchronous image editing without modifying original image disk data
- [x] Animated image smart decoding, decompressing, editing and caching
- [x] Independent image cache, downloader, coder and editor for separate use
- [x] Customized image cache, downloader and coder
- [x] High performance

## Why to Use

### Solve the Problems of SDWebImage

SDWebImage is a powerful library for downloading and caching web images. When BBWebImage first version (0.1.0) is released, the latest version of SDWebImage is 4.4.3 which dose not contain powerful image editing function. If we download an image with SDWebImage 4.4.3 and edit the image, the problems will happen:

1. The edited image is cached, but the original image data is lost. We need to download the original image again if we want to display it.
2. The original image data is cached to disk. If we do not cache the edited image, we need to edit image to display the edited image every time. If we cache the edited image to both memory and disk, we need to write more code and manage the cache key. If we cache the edited image to memory only, when we get the cached image, we need to know whether it is edited by checking where it is cached.
3. If we use `Core Graphics` to edit image, we should disable SDWebImage image decompressing (because decompressing is unnecessary. Both editing and decompressing have similar steps: create `CGContext`, draw image, create new image) and enable it later.

BBWebImage is born to solve the problems.

1. The original image data is cached to disk, and the original or edited image is cached to memory. The `UIImage` is associated with edit key which is a String identifying how the image is edited. Edit key is nil for original image. When we load image from the network or cache, we can pass `BBWebImageEditor` to get edited image. BBWebImageEditor specifies how to edit image, and contains the edit key which will be associated to the edited image. If the edit key of the memory cached image is the same as the edit key of BBWebImageEditor, then the memory cached image is what we need; Or BBWebImage will load and edit the original image and cache the edited image to memory. If we want the original image, do not pass BBWebImageEditor. We will not download an image more than once. We do not need to write more code to cache edited image or check whether the image is edited.
2. If we load original image, BBWebImage will decompress image by default. If we load image with BBWebImageEditor, BBWebImage will use editor to edit image without decompressing. We do not need to write more code to enable or disable image decompressing.

### Edit Animated Amage and Cache Smartly

To display animated image, we need to decode image frames, change frame according to frame duration. We use `BBAnimatedImage` to manage animated image data, and use `BBAnimatedImageView` to play the animation. BBAnimatedImageView decides which frame to display or to decode. BBAnimatedImage decodes and caches image frames in the background. The max cache size is calculated dynamically and the cache is cleared automatically.

BBAnimatedImage uses BBWebImageEditor to edit image frames. BBAnimatedImage has a property `bb_editor` which is an optional BBWebImageEditor type. Set an editor to the property to display edited image frames, or set nil to display original image frames.

## Requirements

- iOS 8.0+
- Swift 4.2

## Installation

Install with CocoaPods:

1. Add `pod 'BBWebImage'` to your Podfile. Add `pod 'BBWebImage/MapKit'` for MKAnnotationView extension. Add `pod 'BBWebImage/Filter'` for image filter.
2. Run `pod install` or `pod update`.
3. Add `import BBWebImage` to the Swift source file.

## How to Use

### View Extensions

The simplest way to use is setting image for `UIImageView` with `URL`

```swift
imageView.bb_setImage(with: url)
```

The code below:

1. Downloads a high-resolution image
2. Downsamples and crops it to match an expected maximum resolution and image view size
3. Draws it with rounded corner, border and background color
4. Displays edited image after downloading and editing
5. Displays a placeholder image before downloading
6. Decodes image incrementally and displays it while downloading
7. Do something while downloading
8. Caches original image data to disk and caches edited image to memory
9. Do something when loading is finished

```swift
let editor = bb_imageEditorCommon(with: imageView.frame.size,
                                  maxResolution: 1024 * 1024,
                                  corner: .allCorners,
                                  cornerRadius: 5,
                                  borderWidth: 1,
                                  borderColor: .yellow,
                                  backgroundColor: .gray)
let progress = { (data: Data?, expectedSize: Int, image: UIImage?) -> Void in
    // Do something while downloading
}
imageView.bb_setImage(with: url,
                      placeholder: UIImage(named: "placeholder"),
                      options: .progressiveDownload,
                      editor: editor,
                      progress: progress)
{ (image: UIImage?, data: Data?, error: Error?, cacheType: BBImageCacheType) in
    // Do something when finish loading
}
```

The parameter `options` of `bb_setImage(with:)` method is `BBWebImageOptions`, an option set. Use it to control some behaviors of downloading, caching, decoding and displaying. The value `.progressiveDownload` means displaying image progressly when downloading. The default value is `.none`.

The parameter `editor` of `bb_setImage(with:)` method is an optional struct `BBWebImageEditor`. Pass nil to display original image. There are other built-in editors to choose. See [Built-in Image Editors](#built-in-image-editors).

To support GIF, replace `UIImageView` by `BBAnimatedImageView`. BBAnimatedImageView is a subclass of UIImageView. BBAnimatedImageView supports both static image and animated image.

To support other image format or change default encode/decode behaivor, see [Supported Image Formats](#supported-image-formats).

### Image Manager

To get image  from cache or the network without displaying on the view, use `BBWebImageManager` `loadImage(with:)` method. The method returns a `BBWebImageLoadTask` object. To cancel the task, call `cancel()` method of the task.

```swift
let progress = { (data: Data?, expectedSize: Int, image: UIImage?) -> Void in
    // Do something while downloading
}
BBWebImageManager.shared.loadImage(with: url,
                                   options: options,
                                   editor: editor,
                                   progress: progress)
{ (image: UIImage?, data: Data?, error: Error?, cacheType: BBImageCacheType) in
    // Do something when finish loading
}
```

### Image Cache

To get image or data from cache, use `BBLRUImageCache` `image(forKey:)` method. To get image/data from memory/disk only, pass `.memory`/`.disk` to `cacheType`.

```swift
BBWebImageManager.shared.imageCache.image(forKey: key,
                                          cacheType: .all)
{ (result: BBImageCacheQueryCompletionResult) in
    switch result {
    case let .memory(image: image): // Do something with memory image
    case let .disk(data: data): // Do something with disk data
    case let .all(image: image, data: data): // Do something with image and data
    default: // Do something when no image or data
    }
}
```

To store image or data to cache, use `store(_:)` method. To store image/data to memory/disk only, pass `.memory`/`.disk` to `cacheType`.

```swift
BBWebImageManager.shared.imageCache.store(image,
                                          data: data,
                                          forKey: key,
                                          cacheType: .all)
{
    // Do something after storing
}
```

To remove image or data from cache, use `removeImage(forKey:)` method. To remove image/data from memory/disk only, pass `.memory`/`.disk` to `cacheType`.

```swift
BBWebImageManager.shared.imageCache.removeImage(forKey: key,
                                                cacheType: .all)
{
    // Do something after removing
}
```

To remove all images or data from cache, use `clear(_:)` method. To remove all image/data from memory/disk only, pass `.memory`/`.disk` to first parameter.

```swift
BBWebImageManager.shared.imageCache.clear(.all) {
    // Do something after clearing
}
```

### Image Downloader

To download image data, use `BBMergeRequestImageDownloader` `download(with:)` method. The method returns a task conforming to `BBImageDownloadTask` protocol. To cancel the task, call downloader `cancel(task:)` method and pass the task as parameter. To cancel all download tasks, call downloader `cancelAll()` method.

```swift
let progress = { (data: Data?, expectedSize: Int, image: UIImage?) -> Void in
    // Do something while downloading
}
BBWebImageManager.shared.imageDownloader.downloadImage(with: url,
                                                       options: options,
                                                       progress: progress)
{ (data: Data?, error: Error?) in
    // Do something with data or error
}
```

### Image Coder

To get decoded image (without decompressing) from data, use `BBImageCoderManager` `decodedImage(with:)` method. The method returns an optional `UIImage` object. If the image is `BBAnimatedImage`, it is an animated image ready for display on `BBAnimatedImageView`. If the image is a static image, it is not decompressed. Use `decompressedImage(with:` method to decompress it for display.

```swift
let coder = BBWebImageManager.shared.imageCoder
if let decodedImage = coder.decodedImage(with: data) {
    // Do something with decoded image
    if let animatedImage = decodedImage as? BBAnimatedImage {
        // Do something with animated image
    } else if let decompressedImage = coder.decompressedImage(with: decodedImage, data: data) {
        // Do something with decompressed image
    } else {
        // Can not decompress image
    }
} else {
    // Can not decode image data
}
```

To encode image to specific format, use `encodedData(with:)` method.

```swift
if let data = coder.encodedData(with: image, format: .PNG) {
    // Do something with data
} else {
    // Can not encode data
}
```

To support other image format or change default encode/decode behaivor, see [Supported Image Formats](#supported-image-formats).

<h2 id="supported-image-formats">Supported Image Formats</h2>

- [x] JPEG
- [x] PNG
- [x] GIF

To support other image format or change default encode/decode behaivor, customize image coder. Implement new coder conforming to `BBImageCoder` protocol. Get old coders and change.

```swift
if let coderManager = BBWebImageManager.shared.imageCoder as? BBImageCoderManager {
    let oldCoders = coderManager.coders
    let newCoders = ...
    coderManager.coders = newCoders
}
```

<h2 id="built-in-image-editors">Built-in Image Editors</h2>

Struct `BBWebImageEditor` defines how to edit and cache image in memory. The built-in image editors are below:

| Editor | Description | Create Method |
| ------ | ------ | ------ |
| Common | Crop and resize image with expected maximum resolution, view size and content mode. Draw rounded corner, border and background color. |`bb_commonEditedImage(with:)`|
| Crop | Crop image to the specific rect. |`bb_croppedImage(with:)`|
| Resize | Resize image to the specific size, or to fit view size and content mode. |`bb_resizedImage(with:)`|
| Rotate | Rotate image with given angle. |`bb_rotatedImage(withAngle:)`|
| Flip | Flip image horizontally and/or vertically. |`bb_flippedImage(withHorizontal:)`|
| Tint | Tint image with color. |`bb_tintedImage(with:)`|
| Tint gradiently | Tint image with gradient color. |`bb_gradientlyTintedImage(with:)`|
| Overlay | Overlay image with another image. |`bb_overlaidImage(with:)`|
| Color lookup | Remap the image colors with color lookup image. |`bb_imageEditorCILookupTestFilter(maxTileSize:)` in demo|

## Architecture

![](README_resources/architecture.png)

## License

BBWebImage is released under the MIT license. See [LICENSE](LICENSE) for details.
