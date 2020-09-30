<p align="center">
<a href="https://github.com/KittenYang/Longinus">
<img src="Assets/Logo.png" alt="Longinus" />
</a>
</p>
<p align="center">
  <a href="https://github.com/KittenYang/Longinus/actions?query=workflow%3Abuild"><img src="https://img.shields.io/github/workflow/status/KittenYang/Longinus/build/master?style=for-the-badge"></a>
  <a href="https://github.com/KittenYang/Longinus/graphs/contributors"><img src="https://img.shields.io/github/contributors/KittenYang/Longinus.svg?style=for-the-badge"></a>
  <a href="https://github.com/KittenYang/Longinus/network/members"><img src="https://img.shields.io/github/forks/KittenYang/Longinus.svg?style=for-the-badge"></a>  
  <a href="https://github.com/KittenYang/Longinus/stargazers"><img src="https://img.shields.io/github/stars/KittenYang/Longinus.svg?style=for-the-badge"></a>  
  <br />
  <a href="https://cocoapods.org/pods/Longinus"><img src="https://img.shields.io/cocoapods/v/Longinus.svg?style=for-the-badge"/></a>
  <a href="https://github.com/Carthage/Carthage/"><img src="https://img.shields.io/badge/Carthage-compatible-ff69b4?style=for-the-badge"></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-compatible-orange?style=for-the-badge"></a> 
  <br />
  <a href="https://cocoapods.org/pods/Longinus"><img src="https://img.shields.io/cocoapods/l/Longinus.svg?style=for-the-badge"/></a>
  <a href="https://cocoapods.org/pods/Longinus"><img src="https://img.shields.io/cocoapods/p/Longinus.svg?style=for-the-badge"/></a>
</p>


# Longinus
Longinus is a pure-Swift high-performance asynchronous web image loading,caching,editing framework.

It was learned from Objective-C web image loading framework [YYWebImage](https://github.com/ibireme/YYWebImage) and [BBWebImage](https://github.com/Silence-GitHub/BBWebImage), bring lots of high performace features to Swift. It may become a better choice for you.

Longinus's goal is to become the Highest-Performance web image loading framework on Swift.

## Feature
* Asynchronous image downloading and caching.
* Preload images and cache them to disk for further showing.
* Animated GIF support (dynamic buffer, lower memory usage).
* Baseline/progressive/interlaced image decode support.
* View extensions for UIImageView, UIButton, MKAnnotationView(not yet) and CALayer to directly set an image from a URL.
* Built-in transition animation when setting images.(or you can set your custom image showing transion)
* Image Transform after downloading supported: blur, round corner, resize, color tint, crop, rotate and more.
* High performance memory and disk image cache. Use LRU algorithm to manage. For disk cache, it use file system and sqlite for better performance.
* Use FIFO queue to handle image downloading operation.
* Smooth sliding without UI lags. High performance image caching and decoding to avoid main thread blocked.
* SwiftUI support.

## Usage

The simplest use-case is setting an image to an image view with the UIImageView extension:
```swift
let url = URL(string: "http://github.com/logo.png")
imageView.lg.setImage(with: url)
```
Load animated gif image:
```swift
let url = URL(string: "https://ww4.sinaimg.cn/bmiddle/eaeb7349jw1ewbhiu69i2g20b4069e86.gif")
imageView.lg.setImage(with: url)
```
Load image progressively:
```swift
let url = URL(string: "http://github.com/logo.png")
imageView.lg.setImage(with: url, options: [.progressiveBlur, .imageWithFadeAnimation])
```
Load and transform image:
```swift
let url = URL(string: "https://ww4.sinaimg.cn/bmiddle/eaeb7349jw1ewbhiu69i2g20b4069e86.gif")
let transformer = ImageTransformer.imageTransformerCommon(with: imageView.frame.size, borderWidth: 2.0, borderColor: .white)
imageView.lg.setImage(with: url, options: [.progressiveBlur, .imageWithFadeAnimation], transformer: transformer)
```
Usage in SwiftUI:
```swift
import SwiftUI

// 1. If you are using SPM or Carthage, the SwiftUI support is defined in a new module.
import LonginusSwiftUI

// 2. If you are using CocoaPods, in which the SwiftUI support is defined in the Longinus module.
//    Here we choose to just import the `LGImage` type instead of the whole module, 
//    to prevent the conflicting between `Longinus.View` and `SwiftUI.View`
import struct Longinus.LGImage

var body: some View {
    LGImage(source: URL(string: "https://github.com/KittenYang/Template-Image-Set/blob/master/Landscape/landscape-\(index).jpg?raw=true"), placeholder: {
            Image(systemName: "arrow.2.circlepath")
                .font(.largeTitle) })
        .onProgress(progress: { (data, expectedSize, _) in
            print("Downloaded: \(data?.count ?? 0)/\(expectedSize)")
        })
        .onCompletion(completion: { (image, data, error, cacheType) in
            if let error = error {
                print(error)
            }
            if let _ = image {
                print("Success！")
            }
        })
        .resizable()
        .cancelOnDisappear(true)
        .aspectRatio(contentMode: .fill)
        .frame(width: 300, height: 300)
        .cornerRadius(20)
        .shadow(radius: 5)
}

```

# Requirements
* iOS 10.0+
* Swift 5.0+
* SwiftUI 13.0+

# Installation
## CocoaPods

Longinus is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:
```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target 'MyApp' do
  # your other pod
  # ...
  pod 'Longinus'
  # SwiftUI support is provided in a sub-spec. 
  # So instead of specifying pod 'Longinus', 
  # you need:
  # pod 'Longinus/SwiftUI'
end
```

Then, run the following command:

```
$ pod install
```

You should open the {Project}.xcworkspace instead of the {Project}.xcodeproj after you installed anything from CocoaPods.

For more information about how to use CocoaPods, I suggest this [tutorial](http://www.raywenderlich.com/64546/introduction-to-cocoapods-2).

## Carthage
[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager for Cocoa application. To install the carthage tool, you can use [Homebrew](http://brew.sh/).

To integrate Longinus into your Xcode project using Carthage, specify it in your Cartfile:

```
github "KittenYang/Longinus" ~> 1.0
```
Then, run the following command to build the Longinus framework:

```
$ carthage update
```

## Swift Package Manager
From Xcode 11, you can use [Swift Package Manager](https://swift.org/package-manager/) to add Longinus to your project.

Select File > Swift Packages > Add Package Dependency. Enter `https://github.com/KittenYang/Longinus.git` in the "Choose Package Repository" dialog.

# Benchmark
I tested some popular web image loading frameworks on iOS platform from some aspects.
* Image loading speed. 
* Memory&Disk read/write/delete speed.
* Scrolling 4000 images UI fps.

Here is the tested results. *(Lower is better)*

*Note: The test device is iPhone 11, running on iOS 13.3*

![](Assets/Image_loading_speed_benchmark.jpeg)

![](Assets/Memory_IO_benchmark.jpeg)

![](Assets/Disk_IO_benchmark.jpeg)


You can git clone this repo and run the `Benchmark.xcworkspace` to test it by yourself.

## License

Longinus is available under the MIT license. See the LICENSE file for more info.

