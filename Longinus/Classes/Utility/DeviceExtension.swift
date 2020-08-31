//
//  DeviceExtension.swift
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
    

import UIKit

extension UIDevice: LonginusCompatible { }
public extension LonginusExtension where Base: UIDevice {
    static var totalMemory: Int64 {
        return Int64(ProcessInfo().physicalMemory)
    }
    
    static var freeMemory: Int64 {
        let host_port = mach_host_self()
        var page_size: vm_size_t = 0
        guard host_page_size(host_port, &page_size) == KERN_SUCCESS else { return -1 }
        var host_size = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
        let hostInfo = vm_statistics_t.allocate(capacity: 1)
        let kern = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(host_size)) {
            host_statistics(host_port, HOST_VM_INFO, $0, &host_size)
        }
        let vm_stat = hostInfo.move()
        hostInfo.deallocate()
        guard kern == KERN_SUCCESS else { return -1 }
        return Int64(page_size) * Int64(vm_stat.free_count)
    }
}
