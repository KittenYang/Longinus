//
//  ImageCodeable.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/13.
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
import UIKit
import MobileCoreServices

public protocol ImageCodeable: AnyObject {

    func canDecode(_ data: Data) -> Bool
    func decodedImage(with data: Data) -> UIImage?
    func decompressedImage(with image: UIImage, data: Data) -> UIImage?
    func canEncode(_ format: ImageFormat) -> Bool
    func encodedData(with image: UIImage, format: ImageFormat) -> Data?
    func copy() -> ImageCodeable
    
}

public protocol ImageProgressiveCodeable: ImageCodeable {
    /// Image coder can decode data incrementally or not
    ///
    /// - Parameter data: data to decode
    /// - Returns: true if image coder can decode data incrementally, or false if can not
    func canIncrementallyDecode(_ data: Data) -> Bool
    
    /// Decodes data incrementally
    ///
    /// - Parameters:
    ///   - data: data to decode
    ///   - finished: whether downloading is finished
    /// - Returns: decoded image, or nil if decoding fails
    func incrementallyDecodedImage(with data: Data, finished: Bool) -> UIImage?
}


public protocol AnimatedImageCodeable {
    var imageData: Data? { get set }
    var frameCount: Int? { get }
    var loopCount: Int?  { get }
    var bytesPerFrame: Int64? { get }
    func imageFrame(at index: Int, decompress: Bool) -> UIImage?
    func imageFrameSize(at index: Int) -> CGSize?
    func duration(at index: Int) -> TimeInterval?
    func contentsRect(at index: Int) -> CGRect?
}

extension AnimatedImageCodeable {
    public func contentsRect(at index: Int) -> CGRect? {
        return CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
    }
}

public enum ImageFormat {
    case unknown
    case JPEG
    case PNG
    case GIF
    
    var UTType: CFString {
        switch self {
        case .JPEG:
            return kUTTypeJPEG
        case .PNG:
            return kUTTypePNG
        case .GIF:
            return kUTTypeGIF
        default:
            return kUTTypeImage
        }
    }
    
    struct HeaderData {
        static var PNG: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        static var JPEG_SOI: [UInt8] = [0xFF, 0xD8]
        static var JPEG_IF: [UInt8] = [0xFF]
        static var GIF: [UInt8] = [0x47, 0x49, 0x46]
    }
    
    /// https://en.wikipedia.org/wiki/JPEG
    public enum JPEGMarker {
        case SOF0           //baseline
        case SOF2           //progressive
        case DHT            //Huffman Table
        case DQT            //Quantization Table
        case DRI            //Restart Interval
        case SOS            //Start Of Scan
        case RSTn(UInt8)    //Restart
        case APPn           //Application-specific
        case COM            //Comment
        case EOI            //End Of Image
        
        var bytes: [UInt8] {
            switch self {
            case .SOF0:         return [0xFF, 0xC0]
            case .SOF2:         return [0xFF, 0xC2]
            case .DHT:          return [0xFF, 0xC4]
            case .DQT:          return [0xFF, 0xDB]
            case .DRI:          return [0xFF, 0xDD]
            case .SOS:          return [0xFF, 0xDA]
            case .RSTn(let n):  return [0xFF, 0xD0 + n]
            case .APPn:         return [0xFF, 0xE0]
            case .COM:          return [0xFF, 0xFE]
            case .EOI:          return [0xFF, 0xD9]
            }
        }
    }
    
}

