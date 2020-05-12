//
//  ViewController.swift
//  Longinus
//
//  Created by KittenYang on 05/11/2020.
//  Copyright (c) 2020 kittenyang@icloud.com. All rights reserved.
//

import UIKit
import Longinus

class Account: Codable {
    var alias: String
    
    init(alias: String) {
        self.alias = alias
    }
}

struct User: Codable, Equatable {
    var isActive: Bool
    var account: Account
    var key: String = ""
    
    init(isActive: Bool, account: Account) {
        self.isActive = isActive
        self.account = account
    }
    
    public static func == (lhs: User, rhs: User) -> Bool {
        return
            lhs.account.alias == rhs.account.alias &&
                lhs.isActive == rhs.isActive
    }
}

 
class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let memoryCache = MemoryCache<String,User>()
        DispatchQueue.concurrentPerform(iterations: 10000) { (index) in
            let user = User(isActive: true, account: Account(alias: "alias\(index)"))
            memoryCache.save(value: user, for: "abc\(index)")
            print("write is \(index)")
            
            print(Thread.current)
            
            DispatchQueue.global().async {
                print("read is \(index)")
                let _ = memoryCache.query(key: "abc\(index)")
            }
        }
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

