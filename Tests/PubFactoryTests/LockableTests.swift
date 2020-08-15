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
