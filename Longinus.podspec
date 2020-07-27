#
# Be sure to run `pod lib lint Longinus.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Longinus'
  s.version          = '1.0.0'
  s.summary          = 'Longinus is a pure-Swift high-performance asynchronous web image loading and caching framework.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
                        Longinus is a pure-Swift high-performance asynchronous web image loading and caching framework.
                        
                        * Asynchronous image downloading and caching.
                        * Preload images and cache them to disk for further showing.
                        * Animated GIF support (dynamic buffer, lower memory usage).
                        * Baseline/progressive/interlaced image decode support.
                        * View extensions for UIImageView, UIButton, MKAnnotationView and CALayer to directly set an image from a URL.
                        * Image loading category for UIImageView, UIButton and CALayer.
                        * Built-in transition animation when setting images.(or you can set your custom image showing transion)
                        * Image Transform after downloading supported: blur, round corner, resize, color tint, crop, rotate and more.
                        * High performance memory and disk image cache. Use LRU algorithm to manage. For disk cache, it use file system and sqlite for better performance.
                        * Use FIFO queue to handle image downloading operation.
                        * Smooth sliding without UI lags. High performance image caching and decoding to avoid main thread blocked.
                       DESC

  s.homepage         = 'https://github.com/KittenYang/Longinus'
  s.screenshots     = 'https://github.com/KittenYang/Longinus/raw/master/Assets/Logo.png'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'KittenYang' => 'kittenyang@icloud.com' }
  s.source           = { :git => 'https://github.com/KittenYang/Longinus.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/KittenYang'

  s.swift_version = "5.0"
  
  s.ios.deployment_target = '9.0'

  s.source_files = 'Longinus/Classes/**/*'
  
  # ---- subspec -----
  s.subspec 'Cache' do |ss|
      ss.source_files = 'Longinus/Classes/Cache/*.swift'
  end
  s.subspec 'Extensions' do |ss|
      ss.source_files = 'Longinus/Classes/Extensions/*.swift'
  end
  s.subspec 'General' do |ss|
       ss.source_files = 'Longinus/Classes/General/*.swift'
  end
  s.subspec 'Image' do |ss|
       ss.source_files = 'Longinus/Classes/Image/*.swift'
  end
  s.subspec 'Networking' do |ss|
       ss.source_files = 'Longinus/Classes/Networking/*.swift'
  end
  s.subspec 'Utility' do |ss|
       ss.source_files = 'Longinus/Classes/Utility/*.swift'
  end
  s.subspec 'Views' do |ss|
       ss.source_files = 'Longinus/Classes/Views/*.swift'
  end
  
  # s.resource_bundles = {
  #   'Longinus' => ['Longinus/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
