//
//  ImageViewCollectionViewController.swift
//  Benchmark
//
//  Created by Qitao Yang on 2020/7/22.
//  Copyright © 2020 Qitao Yang. All rights reserved.
//

import UIKit
import Longinus
import YYWebImage
import SDWebImage
import Kingfisher
import BBWebImage

private let reuseIdentifier = "Cell"

enum WebImageType: Int {
    case longinus = 0
    case yywebimage = 1
    case sdwebimage = 2
    case kingfisher = 3
    case bbwebimage = 4
    
    var name: String {
        switch self {
        case .longinus:
            return "Longinus"
        case .yywebimage:
            return "YYWebImage"
        case .sdwebimage:
            return "SDWebImage"
        case .kingfisher:
            return "Kingfisher"
        case .bbwebimage:
            return "BBWebImage"
        }
    }
}

enum ImageWallType {
    case image
    case gif
}

class ImageViewCollectionViewController: UICollectionViewController {

    let allWebImageType: [WebImageType] = [.longinus, .yywebimage, .sdwebimage, .kingfisher, .bbwebimage]
    var currentType: WebImageType = .longinus
    
    var imageWallType: ImageWallType = .image
    
    lazy var segmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: allWebImageType.compactMap{ $0.name })
        control.selectedSegmentIndex = 0
        return control
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let cellWidth = view.bounds.width / 4
        layout.itemSize = CGSize(width: cellWidth, height: cellWidth)
        self.collectionView!.collectionViewLayout = layout
        self.collectionView!.register(ImageWallCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView.contentInset.bottom += 45.0
        if #available(iOS 10.0, *) {
//            self.collectionView.prefetchDataSource = self
        }
        
        self.view.addSubview(segmentControl)
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        let margins = self.view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            segmentControl.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -10.0),
            segmentControl.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
            segmentControl.widthAnchor.constraint(equalToConstant: 320.0),
            segmentControl.heightAnchor.constraint(equalToConstant: 25.0)
        ])
        segmentControl.addTarget(self, action: #selector(handleSegmentControlValueChangedAction), for: .valueChanged)
        
    }

    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4000
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ImageWallCell
        if let url = getImageURLByIndex(indexPath: indexPath) {
            cell.currentType = currentType
            cell.updateUIWith(url)
        }
        return cell
    }
    
    @objc private func handleSegmentControlValueChangedAction() {
        currentType = WebImageType(rawValue: self.segmentControl.selectedSegmentIndex) ?? .longinus
        collectionView.reloadData()
    }
    
    private func getImageURLByIndex(indexPath: IndexPath) -> URL? {
        var url = ImageLinksPool.originLink(forIndex: indexPath.item + 1)
        switch imageWallType {
        case .gif:
            url = ImageLinksPool.thumbnailGIFLink(forIndex: indexPath.item)
        default:
            break
        }
        return url
    }
}

// MARK: UICollectionViewDataSourcePrefetching
@available(iOS 10.0, *)
extension ImageViewCollectionViewController: UICollectionViewDataSourcePrefetching {
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        if currentType == .longinus {
            let prefetechImageLinks = indexPaths.compactMap({ return getImageURLByIndex(indexPath: $0) })
            LonginusManager.shared.preload(prefetechImageLinks, options: .none, progress: { (successCount, finishCount, total) in
            }) { (successCount, total) in
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        if currentType == .longinus {
            indexPaths.forEach { (indexPath) in
                if let urlString = getImageURLByIndex(indexPath: indexPath)?.absoluteString {
                    LonginusManager.shared.cancelPreloading(url: urlString)
                }
            }
        }
    }

}

class ImageWallCell: UICollectionViewCell {
    
    var currentType: WebImageType = .longinus {
        willSet {
            updateCurrentBenmarkType(type: newValue)
        }
    }
    
    private lazy var lgImageView: Longinus.AnimatedImageView = {
        var imageView = Longinus.AnimatedImageView(frame: CGRect(origin: .zero, size: frame.size))
        imageView.webImageType = .longinus
        imageView.runLoopMode = .common
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var kfImageView: Kingfisher.AnimatedImageView = {
        var imageView = Kingfisher.AnimatedImageView(frame: CGRect(origin: .zero, size: frame.size))
        imageView.webImageType = .kingfisher
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var yyImageView: YYAnimatedImageView = {
        var imageView = YYAnimatedImageView(frame: CGRect(origin: .zero, size: frame.size))
        imageView.webImageType = .yywebimage
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var sdImageView: FLAnimatedImageView = {
        var imageView = FLAnimatedImageView(frame: CGRect(origin: .zero, size: frame.size))
        imageView.webImageType = .sdwebimage
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var bbImageView: BBAnimatedImageView = {
        var imageView = BBAnimatedImageView(frame: CGRect(origin: .zero, size: frame.size))
        imageView.webImageType = .bbwebimage
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    weak var currentShowingImageView: UIImageView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(lgImageView)
        contentView.addSubview(kfImageView)
        contentView.addSubview(yyImageView)
        contentView.addSubview(sdImageView)
        contentView.addSubview(bbImageView)
    }
    
    private func updateCurrentBenmarkType(type: WebImageType) {
        if currentType == type { return }
        let all = [lgImageView, kfImageView, yyImageView, sdImageView, bbImageView]
        all.forEach { (imv) in
            imv.isHidden = imv.webImageType != type
            if !imv.isHidden {
                currentShowingImageView = imv
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateUIWith(_ url: URL) {
        let placeholder = UIImage(named: "placeholder")
        switch currentType {
        case .longinus:
            let radius: CGFloat = min(lgImageView.frame.width, lgImageView.frame.height)
            let transformer = ImageTransformer.imageTransformerCommon(with: CGSize(width: radius, height: radius),
                                                                      fillContentMode: .center,
                                                                      corner: [.allCorners],
                                                                      cornerRadius: 8.0,
                                                                      borderWidth: 4.0,
                                                                      borderColor: UIColor.white,
                                                                      backgroundColor: UIColor.gray)
            lgImageView.lg.setImage(with: url, placeholder: placeholder, options: [.imageWithFadeAnimation, .showNetworkActivity], transformer: transformer, progress: nil, completion: nil)
        case .kingfisher:
            kfImageView.kf.setImage(with: url, placeholder: placeholder)
        case .sdwebimage:
            sdImageView.sd_setImage(with: url, placeholderImage: placeholder, options: [], completed: nil)
        case .yywebimage:
            yyImageView.yy_setImage(with: url, placeholder: placeholder)
        case .bbwebimage:
            bbImageView.bb_setImage(with: url, placeholder: placeholder, options: [.progressiveDownload], editor: nil, progress: nil, completion: nil)
        }
    }
    
}

private var imageWallCellKey: Void?
extension UIImageView {
    
    var webImageType: WebImageType? {
        get {
            return objc_getAssociatedObject(self, &imageWallCellKey) as? WebImageType
        }
        set {
            objc_setAssociatedObject(self, &imageWallCellKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
}
