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
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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
        self.webImageView.lg.setImage(with: url, placeholder: UIImage(named: "placeholder"), options: [.progressiveDownload, .imageWithFadeAnimation], transformer: nil, progress: { (data, progress, image) in
            
        }) { (image, data, error, cacheType) in
            
        }
    }
    
}

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!

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
        return ImageLinksPool.imageLinks.count * 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LonginusExampleCell.nameOfClass, for: indexPath)
        (cell as? LonginusExampleCell)?.updateImageWithURL(url: ImageLinksPool.getImageLink(forIndex: indexPath.row % ImageLinksPool.imageLinks.count))
        return cell
    }
    
    
}
