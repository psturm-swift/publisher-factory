/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import XCTest
@testable import PubFactory

final class LocableTests: XCTestCase {
    func test_correct_locking_with_synchronized_block() {
        let lock = LockCounter()
        
        XCTAssertEqual(lock.counter, 0)
        lock.synchronize {
            XCTAssertEqual(lock.counter, 1)
        }
        XCTAssertEqual(lock.counter, 0)
    }
    
    func test_correct_locking_with_nested_synchronized_blocks() {
        let lock = LockCounter()
        
        XCTAssertEqual(lock.counter, 0)
        lock.synchronize {
            XCTAssertEqual(lock.counter, 1)
            lock.synchronize {
                XCTAssertEqual(lock.counter, 2)
            }
            XCTAssertEqual(lock.counter, 1)
        }
        XCTAssertEqual(lock.counter, 0)

    }

    static var allTests = [
        ("test_correct_locking_with_synchronized_block", test_correct_locking_with_synchronized_block),
        ("test_correct_locking_with_nested_synchronized_blocks", test_correct_locking_with_nested_synchronized_blocks)
    ]
}

fileprivate class LockCounter: Lockable {
    private(set) var counter: Int = 0
    
    func lock() {
        counter += 1
    }
    
    func unlock() {
        counter -= 1
    }
}
