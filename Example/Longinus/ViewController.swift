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
        var imgv = AnimatedImageView(frame: CGRect(origin: .zero, size: frame.size))
        imgv.contentMode = .scaleAspectFit
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
        let radius: CGFloat = min(webImageView.frame.width, webImageView.frame.height)
        let transformer = ImageTransformer.imageTransformerCommon(with: CGSize(width: radius, height: radius),
                                                                  fillContentMode: .center,
                                                                  corner: [.allCorners],
                                                                  cornerRadius: radius/2,
                                                                  borderWidth: 2.0,
                                                                  borderColor: UIColor.white,
                                                                  backgroundColor: UIColor.gray)
        
        // let headerModifier = URLHttpHeadersModifier(httpHeaders:["If-Modified-Since": lastModifiedString(url: url), "Accept" : "image/*;q=0.8"])
        self.webImageView.lg.setImage(with: url, placeholder: UIImage(named: "placeholder"), options: [.progressiveBlur, .imageWithFadeAnimation/*, .ignoreAnimatedImage*/, /*.httpHeadersModifier(headerModifier), .refreshCache*/], transformer: transformer, progress: { (data, expectedSize, image) in
            if let partialData = data, let url = url {
                let progress = min(1, Double(partialData.count) / Double(expectedSize))
                print("\(url.absoluteString): \(progress)")
            }
        }) { (image, data, error, cacheType) in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    private func lastModifiedString(url: URL?) -> String {
        guard let key = url?.absoluteString,
            let modDate = LonginusManager.shared.imageCacher?.diskCache?.getCacheModifiedDateByKey(key: key) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        let lastModifiedStr = formatter.string(from: modDate)
        return lastModifiedStr
    }
    
}

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.title = "Longinus"
        let reloadButtonItem = UIBarButtonItem(title: "Reload", style: .plain, target: self, action: #selector(reload))
        self.navigationItem.rightBarButtonItem = reloadButtonItem
        self.view.backgroundColor = UIColor.white
        tableView.register(LonginusExampleCell.self, forCellReuseIdentifier: LonginusExampleCell.nameOfClass)
    }
    
    @objc func reload() {
        LonginusManager.shared.imageCacher?.remove([.memory,.disk], completion: nil)
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
        return ImageLinksPool.imageLinks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LonginusExampleCell.nameOfClass, for: indexPath)
        #if targetEnvironment(macCatalyst)
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.clipsToBounds = true
        let radius: CGFloat = min(cell.frame.width, cell.frame.height)
        let transformer = ImageTransformer.imageTransformerCommon(with: CGSize(width: radius, height: radius),
                                                                  fillContentMode: .center,
                                                                  corner: [.allCorners],
                                                                  cornerRadius: radius/2,
                                                                  borderWidth: 2.0,
                                                                  borderColor: UIColor.white,
                                                                  backgroundColor: UIColor.gray)
        cell.imageView?.lg.setImage(with: ImageLinksPool.getImageLink(forIndex: indexPath.row % ImageLinksPool.imageLinks.count), placeholder: UIImage(named: "placeholder"), options: [.progressiveBlur, .imageWithFadeAnimation/*, .ignoreAnimatedImage*/], transformer: transformer, progress: nil, completion: nil)
        #else
        (cell as? LonginusExampleCell)?.updateImageWithURL(url: ImageLinksPool.getImageLink(forIndex: indexPath.row % ImageLinksPool.imageLinks.count))
        #endif
        
        return cell
    }
    
    
}
