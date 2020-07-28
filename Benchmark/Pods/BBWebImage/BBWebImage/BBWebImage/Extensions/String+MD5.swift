//
//  String+MD5.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/12.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import Foundation
import CommonCrypto

public extension String {
    var bb_md5: String {
        guard let data = data(using: .utf8) else { return self }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
