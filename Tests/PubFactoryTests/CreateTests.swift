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
        
        let createPublisher = Create<Int, Never> { subscriber in
            thread = Thread {
                var i = 0
                while (!Thread.current.isCancelled) {
                    subscriber.receive(i)
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
    
    func test_create_with_graceful_finish() {
        let testValues = Array(1...10)
        
        let createPublisher = Create<Int, Never> { subscriber in
            let thread = Thread {
                testValues.forEach { subscriber.receive($0) }
                subscriber.receive(completion: .finished)
            }
            thread.start()
            return AnyCancellable { thread.cancel() }
        }
        
        var receivedValues: [Int] = []
        let sink = createPublisher.collect().sink { values in
            receivedValues = values
        }
        
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(receivedValues, testValues)
        
        // Needed to avoid compiler warning
        sink.cancel()
    }

    func test_if_create_publisher_is_paused_if_demand_is_fulfilled_and_resumed_again() {
        let demands = [4,2,5]
        let totalDemand = demands.reduce(0, +)

        let cancellationExpectation = XCTestExpectation(description: "Create publisher cancelled")
        let publisher = Create<Int, Never> { subscriber, context in
            var i = 0
            while !context.cancelled {
                context.waitIfPaused()
                subscriber.receive(i)
                i += 1
            }
            cancellationExpectation.fulfill()
        }
        
        let subscriber = SubscriberWithManualDemand()
        publisher.subscribe(subscriber)

        for demand in demands {
            let expectation = XCTestExpectation(description: "Demand fulfilled")
            subscriber.setDemandFulfilledExpectation(expectation)
            Thread.sleep(forTimeInterval: 0.2)
            subscriber.addDemand(.max(demand))
            wait(for: [expectation], timeout: 5)
        }
        subscriber.cancel()
        wait(for: [cancellationExpectation], timeout: 5)
        XCTAssertEqual(Array(0..<totalDemand), subscriber.receivedElements)
    }

    
    static var allTests = [
        ("test_create_with_cancellation", test_create_with_cancellation),
        ("test_create_with_graceful_finish", test_create_with_graceful_finish)
    ]
}
