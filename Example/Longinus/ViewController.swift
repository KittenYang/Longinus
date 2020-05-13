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

class User: Codable, Equatable {
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
    
    deinit {
        print("user deinit in \(Thread.current)")
    }
}

 
class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    
        let user = User(isActive: true, account: Account(alias: "kitten"))
        DispatchQueue.global().async {
            let _ = user // release in backgroud
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

