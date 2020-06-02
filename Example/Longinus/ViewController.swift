//
//  ViewController.swift
//  Longinus
//
//  Created by KittenYang on 05/11/2020.
//  Copyright (c) 2020 kittenyang@icloud.com. All rights reserved.
//

import UIKit
import Longinus

class LonginusExampleCell: UITableViewCell {
    
    static let nameOfClass: String = "LonginusExampleCell"
    static let cellHeight: CGFloat = 200.0
    
    lazy var webImageView: AnimatedImageView = {
        let imgv = AnimatedImageView(frame: CGRect(origin: .zero, size: frame.size))
        imgv.contentMode = .scaleAspectFill
        imgv.clipsToBounds = true
        return imgv
    }()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func commonInit() {
        self.webImageView.frame = CGRect(x: 10.0, y: 10.0, width: UIScreen.main.bounds.size.width-10.0*2, height: LonginusExampleCell.cellHeight-10.0*2)
        contentView.addSubview(self.webImageView)
    }
    
    func updateImageWithURL(url: URL?) {
        self.webImageView.lg.setImage(with: url, placeholder: UIImage(named: "placeholder"), options: [.progressiveDownload], editor: nil, progress: { (data, progress, image) in
            
        }) { (image, data, error, cacheType) in
            
        }
    }
    
}

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    var imageLinks = ["https://cdn.echoing.tech/images/d380f62c38525610cac17018f0b14e48.jpeg",
                      "https://cdn.echoing.tech/admins/7be6b36e97887e93652362f16bbc14e2.jpg",
                      "https://cdn.echoing.tech/images/2d2e8eda79e02eb22a9f12a778d67383.jpeg",
                      "https://cdn.echoing.tech/images/83a14ccbc00e5306a8b7c34419a06d01.jpeg",
                      "https://cdn.echoing.tech/images/3ac4037477a03e7bb1fa480ac99d9b7d.jpeg",
                      "https://cdn.echoing.tech/images/6e5c449c66a167bf61949e5370d030f7.jpeg",
                      "https://cdn.echoing.tech/images/734ed822e7c44d90a6fee07d0e999fae.jpeg",
                      "https://cdn.echoing.tech/images/fa1afda807f2786ab11fa46a416889fa.jpeg",
                      "https://cdn.echoing.tech/images/2029bb840882db7d85d2c8deed2b873b.jpeg",
                      "https://cdn.echoing.tech/images/11629c9002834e76da3583f731a81225.jpeg",
                      "https://cdn.echoing.tech/images/cd075e5ede96d2ef33edd69fa35710f7.jpeg",
                      "https://cdn.echoing.tech/images/01c5fc512aa04be8847942044ab93f1e.jpeg",
                      "https://cdn.echoing.tech/images/a10189684aef69e3769e94394d79e55e.jpeg",
                      "https://cdn.echoing.tech/images/b4256657d8af57002fc355ad129ff45e.jpeg",
                      "https://cdn.echoing.tech/images/98bd2a566c92bf58046f88a7d691d3ed.jpeg",
                      "https://cdn.echoing.tech/images/71bc09ac00b0c57d5b21ed404658c1c6.jpeg",
                      "https://cdn.echoing.tech/images/8bd95f1731255743b928f922d757b4cc.jpeg",
                      "https://cdn.echoing.tech/images/03f1bf0ce245ecaa1a77bc65f1f3c3f7.jpeg",
                      "https://cdn.echoing.tech/images/2601ec780b0de0208292364c53228bd9.jpeg",
                      "https://cdn.echoing.tech/images/e51de2676cdbfe9cf81735d958bf01f5.jpeg",
                      "https://cdn.echoing.tech/images/edc102ac88bb3e099cf0121d7337f0d6.jpeg"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.title = "Longinus"
        let reloadButtonItem = UIBarButtonItem(title: "Reload", style: .plain, target: self, action: #selector(reload))
        self.navigationItem.rightBarButtonItem = reloadButtonItem
        self.view.backgroundColor = UIColor(white: 0.217, alpha: 1.0)
        tableView.register(LonginusExampleCell.self, forCellReuseIdentifier: LonginusExampleCell.nameOfClass)
    }
    
    @objc func reload() {
        LonginusManager.shared.imageCacher.remove([.memory,.disk], completion: {})
        self.tableView.perform(#selector(UITableView.reloadData), with: nil, afterDelay: 0.1)
    }

}

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return LonginusExampleCell.cellHeight
    }
    
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return imageLinks.count * 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LonginusExampleCell.nameOfClass, for: indexPath)
        (cell as? LonginusExampleCell)?.updateImageWithURL(url: URL(string: imageLinks[indexPath.row % imageLinks.count]))
        return cell
    }
    
    
}
