//
//  MainTableViewController.swift
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

class MainTableViewController: UITableViewController {

    enum BenchmarkType {
        case fps
        case webloading
        case diskIO
        case memoryIO
        case gifWall
        
        var displayTitle: String {
            switch self {
            case .fps:
                return "流畅性评测"
            case .webloading:
                return "网络图片加载速度评测"
            case .diskIO:
                return "磁盘 IO 评测"
            case .memoryIO:
                return "内存 IO 评测"
            case .gifWall:
                return "GIF 性能评测"
            }
        }
        
        var assosiatedController: UIViewController {
            switch self {
            case .fps:
                return ImageViewCollectionViewController.loadFromNib()
            case .webloading:
                return WebImageLoadingViewController()
            case .diskIO:
                return CacheIOViewController(cacheType: .disk)
            case .memoryIO:
                return CacheIOViewController(cacheType: .memory)
            case .gifWall:
                let gifVC = ImageViewCollectionViewController.loadFromNib() as! ImageViewCollectionViewController
                gifVC.imageWallType = .gif
                return gifVC
            }
        }
    }

    private var menu: [BenchmarkType] = [.fps, .webloading, .diskIO, .memoryIO, .gifWall]
    
    lazy var fps: FPSLabel = {
        let label = FPSLabel()
        return label
    }()
    
    lazy var loading: UIActivityIndicatorView = {
        return UIActivityIndicatorView(style: .gray)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        tableView.dataSource = self
        tableView.delegate = self
        
        self.navigationController?.navigationBar.addSubview(fps)
        self.title = "iOS 网络图片库性能评测"
        if let navBarMargins = self.navigationController?.navigationBar.layoutMarginsGuide {
            fps.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                fps.bottomAnchor.constraint(equalTo: navBarMargins.bottomAnchor, constant: -10.0),
                fps.rightAnchor.constraint(equalTo: navBarMargins.rightAnchor, constant: -10.0),
                fps.widthAnchor.constraint(equalToConstant: 60.0),
                fps.heightAnchor.constraint(equalToConstant: 25.0)
            ])
        }
        
        self.view.addSubview(loading)
        loading.translatesAutoresizingMaskIntoConstraints = false
        let margins = self.view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            loading.centerYAnchor.constraint(equalTo: margins.centerYAnchor),
            loading.centerXAnchor.constraint(equalTo: margins.centerXAnchor)
        ])
    }

    /// MARK: UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menu.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        if indexPath.row == menu.count {
            cell.textLabel?.text = "清除缓存"
            cell.textLabel?.textColor = .red
        } else {
            cell.textLabel?.text = menu[indexPath.row].displayTitle
            cell.textLabel?.textColor = .black
        }
        return cell
    }
    
    /// MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == menu.count {
            loading.startAnimating()
            LonginusManager.shared.imageCacher?.removeAll()
//            KingfisherManager.shared.cache.clearMemoryCache()
//            KingfisherManager.shared.cache.clearDiskCache()
            SDWebImageManager.shared.imageCache.clear(with: .disk, completion: nil)
//            SDWebImageManager.shared.imageCache.clearDisk(onCompletion: nil)
            YYWebImageManager.shared().cache?.memoryCache.removeAllObjects()
            YYWebImageManager.shared().cache?.diskCache.removeAllObjects()
            loading.stopAnimating()
        } else {
            let vc = menu[indexPath.row].assosiatedController
            vc.title = menu[indexPath.row].displayTitle
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

}

extension UIViewController {
    open class func loadFromNib() -> UIViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: NSStringFromClass(self).components(separatedBy: ".").last!)
    }
}

