//
//  ImageWallCollectionViewController.swift
//  Longinus_Example
//
//  Created by Qitao Yang on 2020/7/6.
//
//  Copyright (c) 2020 KittenYang <kittenyang@icloud.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
    

import UIKit
import Longinus

private let reuseIdentifier = "Cell"

class ImageWallCollectionViewController: UICollectionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let cellWidth = view.bounds.width / 4
        layout.itemSize = CGSize(width: cellWidth, height: cellWidth)
        self.collectionView!.collectionViewLayout = layout
        self.collectionView!.register(ImageWallCell.self, forCellWithReuseIdentifier: reuseIdentifier)
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
        if let url = ImageLinksPool.originLink(forIndex: indexPath.item + 1) {
            cell.updateUIWith(url)
        }
        return cell
    }

}


class ImageWallCell: UICollectionViewCell {
    private var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView = UIImageView(frame: CGRect(origin: .zero, size: frame.size))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateUIWith(_ url: URL) {
        let transformer = LonginusExtension<ImageTransformer>
            .imageTransformerCommon(with: imageView.frame.size,
                               corner: .allCorners,
                               cornerRadius: 5.0,
                               borderWidth: 1.0,
                               borderColor: .white,
                               backgroundColor: .green)
        imageView.lg.setImage(with: url, placeholder: UIImage(named: "placeholder"), options: [.progressiveDownload, .showNetworkActivity], transformer: transformer, progress: nil, completion: nil)
    }
}
