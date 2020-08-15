/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import XCTest
import Combine
@testable import PubFactory

final class CreateTests: XCTestCase {
    func test_create_with_cancellation() {
        var receivedValues: [Int] = []
        var thread: Thread?
        
        let createPublisher = Create<Int, Never> { proxy in
            thread = Thread {
                var i = 0
                while (!Thread.current.isCancelled) {
                    proxy.receive(i)
                    i += 1
                }
            }
            thread?.start()
            return AnyCancellable {
                thread?.cancel()
            }
        }
        
        // Block has not been called and thread is still nill
        XCTAssertNil(thread)

        let sink = createPublisher.sink { value in
            receivedValues.append(value)
        }

        // Block has been called and thread has been created
        XCTAssertNotNil(thread)
        
        // Sink is not blocking
        XCTAssertTrue(thread?.isExecuting ?? false)

        // Let publisher produce values for 100ms and then cancel subscription
        Thread.sleep(forTimeInterval: 0.1)
        sink.cancel()

        // Wait for thread to get terminated (500ms)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(thread?.isFinished ?? false)
        XCTAssertGreaterThan(receivedValues.count, 1000)

        for item in receivedValues.enumerated() {
            XCTAssertEqual(item.element, item.offset)
        }
    }

    static var allTests = [
        ("test_create_with_cancellation", test_create_with_cancellation),
    ]
}