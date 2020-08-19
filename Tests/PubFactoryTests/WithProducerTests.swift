/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import XCTest
import Combine
@testable import PubFactory

final class WithProducerTests: XCTestCase {
    func test_if_producer_is_paused_if_demand_is_fulfilled_and_resumed_again() {
        let producer = Counter(5)
        let publisher = WithProducer(producer)
        let demandExpectation = XCTestExpectation(description: "Demand fulfilled")
        let completionExpectation = XCTestExpectation(description: "Completion")
        let subscriber = SubscriberWithManualDemand(
            demandFulfilledExpectation: demandExpectation,
            completionExpectation: completionExpectation)
        publisher.subscribe(subscriber)

        subscriber.addDemand(.max(4))
        wait(for: [demandExpectation], timeout: 5)
        XCTAssertEqual(producer.callsToPause, 1)
        XCTAssertEqual(producer.callsToResume, 0)

        subscriber.addDemand(.max(2))
        wait(for: [completionExpectation], timeout: 5)
        XCTAssertEqual(producer.callsToPause, 1)
        XCTAssertEqual(producer.callsToResume, 1)
    }
    
    func test_correct_backpressure_handling() {
        let demands = [4,2,5]
        let totalDemand = demands.reduce(0, +)
        let completionExpectation = XCTestExpectation(description: "Publisher terminates")
        
        let producer = Counter(totalDemand)
        let publisher = WithProducer(producer)
        let subscriber = SubscriberWithManualDemand(completionExpectation: completionExpectation)
        publisher.subscribe(subscriber)

        var expectedPauseCount = 1
        
        for demand in demands {
            let expectation = XCTestExpectation(description: "Demand fulfilled")
            subscriber.setDemandFulfilledExpectation(expectation)
            subscriber.addDemand(.max(demand))
            wait(for: [expectation], timeout: 5)

            XCTAssertEqual(producer.callsToStart, 1)
            XCTAssertEqual(producer.callsToCancel, 0)
            XCTAssertEqual(producer.callsToPause, expectedPauseCount)
            XCTAssertEqual(producer.callsToResume, expectedPauseCount - 1)
            
            expectedPauseCount += 1
        }
        XCTAssertEqual(Array(0..<totalDemand), subscriber.receivedElements)
    }

    static var allTests = [
        ("test_if_producer_is_paused_if_demand_is_fulfilled_and_resumed_again", test_if_producer_is_paused_if_demand_is_fulfilled_and_resumed_again),
        ("test_correct_backpressure_handling", test_correct_backpressure_handling)
    ]
}
