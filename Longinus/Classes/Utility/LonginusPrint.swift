//
//  LonginusPrint.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/7/22.
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

public func LGPrint(_ object: @autoclosure() -> Any?,
                    _ file: String = #file,
                    _ function: String = #function,
                    _ line: Int = #line) {
    #if DEBUG
    guard let value = object () else { return }
    var stringRepresentation : String?
    if let value = value as? CustomDebugStringConvertible {
        stringRepresentation = value.debugDescription
    } else if let value = value as? CustomStringConvertible {
        stringRepresentation = value.description
    } else {
        fatalError (
            "gLog only works for values that conform to CustomDebugStringConvertible or CustomStringConvertible"
        )
    }
    let gFormatter = DateFormatter ()
    gFormatter.dateFormat = "HH:mm:ss:SSS"
    let timestamp = gFormatter.string (from: Date())
    let queue = Thread.isMainThread ? "Main" : "Background"
    let fileURL = NSURL (string: file)?.lastPathComponent ?? "Unknown file"
    if let string = stringRepresentation {
        print ("🗡 \(timestamp) {\(queue)} \(fileURL) > \(function)[\(line)]: \(string)")
    }
    else {
        print ("🗡 \(timestamp) {\(queue)} \(fileURL) > \(function)[\(line)]: \(value)")
    }
    #endif
}


