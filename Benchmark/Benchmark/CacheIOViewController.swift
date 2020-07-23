//
//  CacheIOViewController.swift
//  Benchmark
//
//  Created by Qitao Yang on 2020/7/23.
//  Copyright © 2020 Qitao Yang. All rights reserved.
//

import UIKit
import Longinus
import YYWebImage
import SDWebImage
import Kingfisher

class CacheIOViewController: ConsoleLabelViewController {

    enum CacheType {
        case memory
        case disk
    }
    
    var currentCacheType: CacheType
    
    init(cacheType: CacheType) {
        self.currentCacheType = cacheType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        currentCacheType = .memory
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getTestImages { [weak self] in
            DispatchQueue.global().async {
                self?.testCache()
            }
        }
    }
    
    private var allTestImages = [(String, UIImage)]()
    private func getTestImages(imagesReady: @escaping ()->Void) {
        var loadDoneCount: Int = 0
        for i in 0..<300 {
            guard let url = ImageLinksPool.originLink(forIndex: i+1) else {
                continue
            }
            LonginusManager.shared.loadImage(with: url, options: .none, transformer: nil, progress: nil) {  (image, data, error, cacheType) in
                loadDoneCount += 1
                if let image = image {
                    self.allTestImages.append((url.absoluteString,image))
                }
                if 300 == loadDoneCount {
                    imagesReady()
                }
            }
        }
    }
    
    private func testCache() {
        switch self.currentCacheType {
        case .disk:
            testDiskCache()
        case .memory:
            testMemoryCache()
        }
    }
    
    private func testMemoryCache() {
        updateConsole(newText: "开始测试\n")
        var storeTime: Double = 0
        var getTime: Double = 0
        var removeTime: Double = 0
        let loopCount = 1000
        func setInitial() {
            storeTime = 0
            getTime = 0
            removeTime = 0
        }
        
        // Longinus
        for _ in 0..<loopCount {
            if exited { return }
            var startTime = CACurrentMediaTime()
            for item in allTestImages {
                LonginusManager.shared.imageCacher.store(item.1, data: nil, forKey: item.0, cacheType: .memory, completion: nil)
            }
            storeTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                LonginusManager.shared.imageCacher.image(forKey: item.0, cacheType: .memory) { (_) in
                }
            }
            getTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                LonginusManager.shared.imageCacher.removeImage(forKey: item.0, cacheType: .memory, completion: nil)
            }
            removeTime += CACurrentMediaTime() - startTime
        }
        updateConsole(newText: String(format: "Longinus 内存存取测试结果: \n存储时间 %0.4f秒\n读取时间 %0.4f秒\n移除时间 %0.4f秒\n", storeTime, getTime, removeTime))
        setInitial()
        
        // YYWebImage
        for item in allTestImages {
            item.1.yy_isDecodedForDisplay = true
        }
        for _ in 0..<loopCount {
            if exited { return }
            var startTime = CACurrentMediaTime()
            for item in allTestImages {
                YYWebImageManager.shared().cache?.setImage(item.1, imageData: nil, forKey: item.0, with: .memory)
            }
            storeTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                let image = YYWebImageManager.shared().cache?.getImageForKey(item.0, with: .memory)
                assert(image != nil)
            }
            getTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                YYWebImageManager.shared().cache?.removeImage(forKey: item.0, with: .memory)
            }
            removeTime += CACurrentMediaTime() - startTime
        }
        updateConsole(newText: String(format: "YYWebImage 内存存取测试结果: \n存储时间 %0.4f秒\n读取时间 %0.4f秒\n移除时间 %0.4f秒\n", storeTime, getTime, removeTime))
        setInitial()
        
        // SDWebImage
        for _ in 0..<loopCount {
            if exited { return }
            var startTime = CACurrentMediaTime()
            for item in allTestImages {
                SDWebImageManager.shared().imageCache?.store(item.1, imageData: nil, forKey: item.0, toDisk: false, completion: nil)
            }
            storeTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                let image = SDWebImageManager.shared().imageCache?.imageFromMemoryCache(forKey: item.0)
                assert(image != nil)
            }
            getTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                SDWebImageManager.shared().imageCache?.removeImage(forKey: item.0, fromDisk: false, withCompletion: nil)
            }
            removeTime += CACurrentMediaTime() - startTime
        }
        updateConsole(newText: String(format: "SDWebImage 内存存取测试结果: \n存储时间 %0.4f秒\n读取时间 %0.4f秒\n移除时间 %0.4f秒\n", storeTime, getTime, removeTime))
        setInitial()

        // Kingfisher
        for _ in 0..<loopCount {
            if exited { return }
            var startTime = CACurrentMediaTime()
            for item in allTestImages {
                KingfisherManager.shared.cache.store(item.1,
                                                     forKey: item.0,
                                                     options: KingfisherParsedOptionsInfo([.cacheMemoryOnly]),
                                                     toDisk: false)
            }
            storeTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                let image = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: item.0)
                assert(image != nil)
            }
            getTime += CACurrentMediaTime() - startTime
            
            startTime = CACurrentMediaTime()
            for item in allTestImages {
                KingfisherManager.shared.cache.removeImage(forKey: item.0, fromMemory: true, fromDisk: false, completionHandler: nil)
            }
            removeTime += CACurrentMediaTime() - startTime
        }
        updateConsole(newText: String(format: "Kingfisher 内存存取测试结果: \n存储时间 %0.4f秒\n读取时间 %0.4f秒\n移除时间 %0.4f秒\n", storeTime, getTime, removeTime))
        
        DispatchQueue.main.async {
            self.loading.stopAnimating()
        }
        
    }
    
    private func testDiskCache() {
        
    }
    
}
