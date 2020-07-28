//
//  DispatchQueue+Safe.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/8.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

extension DispatchQueue {
    func bb_safeAsync(_ work: @escaping () -> Void) {
        if label == String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) {
            work()
        } else {
            async(execute: work)
        }
    }
    
    func bb_safeSync(_ work: @escaping () -> Void) {
        if label == String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) {
            work()
        } else {
            sync(execute: work)
        }
    }
}
