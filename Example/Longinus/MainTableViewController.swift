//
//  MainTableViewController.swift
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

class MainTableViewController: UITableViewController {

    private lazy var fps: FPSLabel = {
        let label = FPSLabel()
        return label
    }()
    private var menu = [(String, (() -> Void)?)]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue(label: "hello", qos: .default, target: DispatchQueue.global(qos: .default)).async {
            print("当前线程:\(Thread.current), hello")
        }
        let common = { [weak self] in
            if let self = self { self.navigationController?.pushViewController(ViewController.loadFromNib(), animated: true) }
        }
        let collectionWall = { [weak self] in
            if let self = self { self.navigationController?.pushViewController(ImageWallCollectionViewController.loadFromNib(), animated: true) }
        }
        menu.append(contentsOf:[
            ("Common", common),
            ("Collection wall", collectionWall)
        ])
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        tableView.dataSource = self
        tableView.delegate = self
    
        if let window = UIApplication.shared.keyWindow {
            fps.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(fps)
            let margins = window.layoutMarginsGuide
            NSLayoutConstraint.activate([
                fps.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -10.0),
                fps.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
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
        cell.textLabel?.text = menu[indexPath.row].0
        return cell
    }
    
    /// MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        menu[indexPath.row].1?()
    }
}

extension UIViewController {
    open class func loadFromNib() -> UIViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: NSStringFromClass(self).components(separatedBy: ".").last!)
    }
}
