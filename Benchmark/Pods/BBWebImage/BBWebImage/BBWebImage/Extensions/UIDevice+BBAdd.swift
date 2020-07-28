//
//  UIDevice+BBAdd.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2/11/19.
//  Copyright © 2019 Kaibo Lu. All rights reserved.
//

import UIKit

extension UIDevice {
    static var bb_totalMemory: Int64 { return Int64(ProcessInfo().physicalMemory) }
    
    static var bb_freeMemory: Int64 {
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
