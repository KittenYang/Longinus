//
//  MainTableViewController.swift
//  Benchmark
//
//  Created by Qitao Yang on 2020/7/22.
//  Copyright © 2020 Qitao Yang. All rights reserved.
//

import UIKit

class MainTableViewController: UITableViewController {

    enum BenchmarkType {
        case fps
        case webloading
        case diskIO
        case memoryIO
        case cpuMemoryUsage
        
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
            case .cpuMemoryUsage:
                return "内存/CPU占用评测"
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
            case .cpuMemoryUsage:
                return WebImageLoadingViewController()
            }
        }
    }

    private var menu: [BenchmarkType] = [.fps, .webloading, .diskIO, .memoryIO, .cpuMemoryUsage]
    
    lazy var fps: FPSLabel = {
        let label = FPSLabel()
        return label
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
    }

    /// MARK: UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menu.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        cell.textLabel?.text = menu[indexPath.row].displayTitle
        return cell
    }
    
    /// MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = menu[indexPath.row].assosiatedController
        vc.title = menu[indexPath.row].displayTitle
        self.navigationController?.pushViewController(vc, animated: true)
    }

}

extension UIViewController {
    open class func loadFromNib() -> UIViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: NSStringFromClass(self).components(separatedBy: ".").last!)
    }
}

