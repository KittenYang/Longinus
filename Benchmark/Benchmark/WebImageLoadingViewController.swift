//
//  WebImageLoadingViewController.swift
//  Benchmark
//
//  Created by Qitao Yang on 2020/7/22.
//  Copyright © 2020 Qitao Yang. All rights reserved.
//

import UIKit
import Longinus
import YYWebImage
import SDWebImage
//import Kingfisher
import BBWebImage

class ConsoleLabelViewController: UIViewController {
    
    var exited: Bool = false
    
    lazy var loading: UIActivityIndicatorView = {
        return UIActivityIndicatorView(style: .gray)
    }()
        
    lazy var consoleLabel: UITextView = {
        let label = UITextView()
        label.font = UIFont.systemFont(ofSize: 16.0)
        label.textColor = UIColor.black
        label.isEditable = false
        label.alwaysBounceVertical = true
        label.showsVerticalScrollIndicator = true
        label.clipsToBounds = true
        label.text = "准备测试...\n"
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        
        //label
        let margins = self.view.layoutMarginsGuide
        self.view.addSubview(consoleLabel)
        consoleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            consoleLabel.centerYAnchor.constraint(equalTo: margins.centerYAnchor),
            consoleLabel.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
            consoleLabel.widthAnchor.constraint(equalToConstant: 300.0),
            consoleLabel.heightAnchor.constraint(equalToConstant: 550.0)
        ])
        
        //loading
        self.view.addSubview(loading)
        loading.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loading.centerYAnchor.constraint(equalTo: margins.centerYAnchor),
            loading.centerXAnchor.constraint(equalTo: margins.centerXAnchor)
        ])
        loading.startAnimating()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        exited = true
        cancelAll()
    }
    
    func updateConsole(newText: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.consoleLabel.text = "\(self.consoleLabel.text ?? "")\n \(newText)\n"
            }
        } else {
            self.consoleLabel.text = "\(self.consoleLabel.text ?? "")\n \(newText)\n"
        }
    }
    
    private func cancelAll() {
        LonginusManager.shared.cancelAll()
//        KingfisherManager.shared.downloader.cancelAll()
        SDWebImageManager.shared.cancelAll()
        YYWebImageManager.shared().queue?.cancelAllOperations()
        BBWebImageManager.shared.cancelAll()
    }
}

class WebImageLoadingViewController: ConsoleLabelViewController {
    
    lazy var results: [WebImageType: [TimeInterval]] = {
        return [WebImageType.longinus: [TimeInterval](),
                WebImageType.yywebimage: [TimeInterval](),
                WebImageType.sdwebimage: [TimeInterval](),
                WebImageType.kingfisher: [TimeInterval](),
                WebImageType.bbwebimage: [TimeInterval]()]
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        runTestFromBeginning()
    }

    deinit {
        print("WebImageLoadingViewController deinit!")
    }
    
    func runTestFromBeginning() {
        SDWebImageManager.shared.imageCache.clear(with: .all, completion: nil)
        self.runTest(type: .longinus)
    }
    
    var runtime = 5 // get 5-times tesy average result
    func runTest(type: WebImageType) {
        var loadDoneCount: Int = 0
        var errorCount: Int = 0
        var successCount: Int = 0
        let testCount = 50
        var startTime = CACurrentMediaTime()
        updateConsole(newText: "* \(type.name) 正在下载......")
        func done(image: UIImage?, error: Error?) {
            DispatchQueue.main.async {
                loadDoneCount += 1
                if image != nil && error == nil {
                    successCount += 1
                } else {
                    errorCount += 1
                }
                if testCount == loadDoneCount {
                    let time = CACurrentMediaTime() - startTime
                    self.updateConsole(newText: "🎉 \(type.name) 下载完成：\n共 \(testCount) 张\n耗时 \(time) 秒\n成功 \(successCount) 张\n失败 \(errorCount) 张")
                    self.results[type]?.append(time)
                    if let next = WebImageType(rawValue: type.rawValue + 1) {
                        self.runTest(type: next)
                    } else {
                        self.updateConsole(newText: "\n测试结束！")
                        self.runtime -= 1
                        if self.runtime != 0 {
                            self.consoleLabel.text = "第 \(5-self.runtime + 1) 次测试...\n"
                            self.runTestFromBeginning()
                        } else {
                            self.loading.stopAnimating()
                            self.calculateAverageResult()
                        }
                    }
                }
            }
        }
        func progress(receivedSize: Int, _ expectedSize: Int) {
            DispatchQueue.main.async {
                let downloadProgress = min(1, Double(receivedSize) / Double(expectedSize))
                print("- \(type.name) 下载进度：\(downloadProgress)")
            }
        }
        if exited { return }
        for i in 0..<testCount {
            if exited { return }
            guard let url = ImageLinksPool.originLink(forIndex: i+1) else {
                continue
            }
            switch type {
            case .longinus:
                LonginusManager.shared.loadImage(
                    with: url,
                    options: [.refreshCache],
                    progress: { (data, expectedSize, image) in
                    progress(receivedSize: data?.count ?? 0, expectedSize)
                }) { (image, data, error, cacheType) in
                    done(image: image, error: error)
                }
            case .kingfisher:
                break
//                KingfisherManager.shared.retrieveImage(
//                    with: url,
//                    options: [.forceRefresh],
//                    progressBlock: { (receivedSize, expectedSize) in
//                    progress(receivedSize: Int(receivedSize), Int(expectedSize))
//                }, downloadTaskUpdated: nil) { (result) in
//                    switch result {
//                    case .success(let _result):
//                        done(image: _result.image, error: nil)
//                    case .failure(let _error):
//                        done(image: nil, error: _error)
//                    }
//                }
            case .sdwebimage:
                break
//                SDWebImageManager.shared.loadImage(with: url, options: [.cacheMemoryOnly,.refreshCached], progress: { (receivedSize, expectedSize, url) in
//                    progress(receivedSize: Int(receivedSize), Int(expectedSize))
//                }) { (image, data, error, cacheType, finished, imageURL) in
//                    done(image: image, error: error)
//                }
//                SDWebImageManager.shared.loadImage(
//                    with: url,
//                    options: [.cacheMemoryOnly,.refreshCached],
//                    progress: { (receivedSize, expectedSize, url) in
//                    progress(receivedSize: Int(receivedSize), Int(expectedSize))
//                }) { (image, data, error, cacheType, finished, imageURL) in
//                    done(image: image, error: error)
//                }
            case .yywebimage:
                YYWebImageManager.shared().requestImage(
                    with: url,
                    options: [.refreshImageCache],
                    progress: { (receivedSize, expectedSize) in
                    progress(receivedSize: Int(receivedSize), Int(expectedSize))
                }, transform: nil) { (image, url, fromType, stage, error) in
                    done(image: image, error: error)
                }
            case .bbwebimage:
                BBWebImageManager.shared.loadImage(with: url, options: [.refreshCache], editor: nil, progress: { (data, expectedSize, image) in
                    progress(receivedSize: data?.count ?? 0, expectedSize)
                }) { (image, data, error, cacheType) in
                    done(image: image, error: error)
                }
            }
        }

    }
    
    func calculateAverageResult() {
        consoleLabel.text = "5次平均测试结果\n"
        for (type, result) in self.results {
            updateConsole(newText: "\(type.name) 下载耗时：\(result.average())\n")
        }
    }

}


extension Sequence where Element: AdditiveArithmetic {
    /// Returns the total sum of all elements in the sequence
    func sum() -> Element { reduce(.zero, +) }
}

extension Collection where Element: BinaryFloatingPoint {
    /// Returns the average of all elements in the array
    func average() -> Element { isEmpty ? .zero : Element(sum()) / Element(count) }
}
