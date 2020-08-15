/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import XCTest
import Combine
@testable import PubFactory

final class ClosureProducerTests: XCTestCase {
    func test_closure_producer_with_cancellation() {
        var threadIsFinished = false
        
        let producer = ClosureProducer<Int, TestError> { proxy in
            let thread = Thread {
                var i = 0
                while (!Thread.current.isCancelled) {
                    proxy.receive(i)
                    i += 1
                }
            }
            thread.start()
            return AnyCancellable {
                proxy.receive(completion: .finished)
                thread.cancel()
                // Wait for thread to get terminated (500ms)
                Thread.sleep(forTimeInterval: 0.5)
                threadIsFinished = thread.isFinished
            }
        }
        
        let delegate = TestProxyDelegate<Int, TestError>()
        let proxy = Proxy(delegate: delegate)
        producer.start(with: proxy)
        Thread.sleep(forTimeInterval: 0.5)
        producer.cancel()
        
        XCTAssert(threadIsFinished)
        XCTAssertGreaterThan(delegate.receivedValues.count, 1000)
        XCTAssertEqual(delegate.receivedCompletions, [.finished])

        for item in delegate.receivedValues.enumerated() {
            XCTAssertEqual(item.element, item.offset)
        }
    }

    static var allTests = [
        ("test_closure_producer_with_cancellation", test_closure_producer_with_cancellation),
    ]
}
