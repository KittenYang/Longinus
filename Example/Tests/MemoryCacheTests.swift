//
//  MemoryCacheTests.swift
//  Longinus_Tests
//
//  Created by Qitao Yang on 2020/5/12.
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
    

import XCTest
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

class MemoryCacheTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_memory_contain_thread_safe() {
        let ext = self.expectation(description: "ext")
        let exeCount = 1000
        let memoryCache = MemoryCache<String, User>()
        
        DispatchQueue.concurrentPerform(iterations: exeCount) { (index) in
            let user = User(isActive: true, account: Account(alias: "alias_\(index)"))
            let key = "abc\(index)"
            memoryCache.save(value: user, for: key)
            print("write totalCount \(memoryCache.totalCount)")
            
            DispatchQueue.global().async {
                let cacheUser = memoryCache.query(key: key)
                print("read is \(cacheUser?.account.alias ?? "无")")
                print("read totalCount \(memoryCache.totalCount)")
                if index == exeCount - 1 {
                    print("结束了！！")
                    ext.fulfill()
                }
            }
        }
        wait(for: [ext], timeout: 200)
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
