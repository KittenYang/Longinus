//
//  NetworkIndicatorManager.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/7/28.
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
    

import Foundation

/**
 This extension to handle Network Indicator operation
 */
private var networkIndicatorInfoKey: Void?
class NetworkIndicatorManager {

    struct ImageApplicationNetworkIndicatorInfo {
        var count: Int = 0
        var timer: Timer?
    }
    
    private static var networkIndicatorInfo: ImageApplicationNetworkIndicatorInfo? {
        get {
            return getAssociatedObject(self, &networkIndicatorInfoKey)
        }
        set {
            setRetainedAssociatedObject(self, &networkIndicatorInfoKey, newValue)
        }
    }
    
    public static let sharedApplication: UIApplication? = { () -> UIApplication? in
        var isAppExtension: Bool = false
        DispatchQueue.once {
            let bundleUrl: URL = Bundle.main.bundleURL
            let bundlePathExtension: String = bundleUrl.pathExtension
            isAppExtension = bundlePathExtension == "appex"
        }
        return isAppExtension ? nil : UIApplication.shared
    }()
    
    
    @objc private static func delaySetActivity(timer: Timer?) {
        guard let app = sharedApplication, let visiable = timer?.userInfo as? Bool else { return }
        if app.isNetworkActivityIndicatorVisible != visiable {
            app.isNetworkActivityIndicatorVisible = visiable
        }
        timer?.invalidate()
    }
    
    private static func changeNetworkActivityCount(delta: Int) {
        if sharedApplication == nil { return }
        let block: ()->Void = {
            var info = networkIndicatorInfo ?? ImageApplicationNetworkIndicatorInfo()
            networkIndicatorInfo = info
            var count = info.count
            count += delta
            info.count = count
            info.timer?.invalidate()
            info.timer = Timer(timeInterval: (1/30.0), target: self, selector: #selector(delaySetActivity(timer:)), userInfo: info.count > 0, repeats: false)
            RunLoop.main.add(info.timer!, forMode: .common)
        }
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    static func incrementNetworkActivityCount() {
        changeNetworkActivityCount(delta: 1)
    }

    static func decrementNetworkActivityCount() {
        changeNetworkActivityCount(delta: -1)
    }

    static func currentNetworkActivityCount() -> Int {
        return networkIndicatorInfo?.count ?? 0
    }

}
