//
//  ImageLinksPool.swift
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
    

import Foundation

class ImageLinksPool {
    
    static func originLink(forIndex index: Int) -> URL? {
        if index < 1 || index > 4000 { return nil }
        return URL(string: "http://qzonestyle.gtimg.cn/qzone/app/weishi/client/testimage/origin/\(index).jpg")
    }
    
    static func thumbnailLink(forIndex index: Int) -> URL? {
        if index < 1 || index > 4000 { return nil }
        return URL(string: "http://qzonestyle.gtimg.cn/qzone/app/weishi/client/testimage/64/\(index).jpg")
    }
    
    //"https://media1.giphy.com/media/SjxtmBS267NOU/200w.webp?cid=ecf05e47efe3f937c498d3f05d0b1e64d8cc7eebcee51f85&rid=200w.webp"
    static let imageLinks = [
                      "https://media.tenor.com/images/962877f1845be69d8fa026fbab9916a0/tenor.gif"]
    /*
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
     "https://cdn.echoing.tech/images/edc102ac88bb3e099cf0121d7337f0d6.jpeg"
     */
    
    static func getImageLink(forIndex index: Int) -> URL? {
        if index < 0 || index >= imageLinks.count { return nil }
        return URL(string: imageLinks[index])
    }
    
}
