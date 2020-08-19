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
    func test_correct_backpressure_handling() {
        let demands = [4,2,5]
        let totalDemand = demands.reduce(0, +)
        let expectation = XCTestExpectation(description: "Publisher terminates")
        
        let producer = Counter(totalDemand)
        let publisher = WithProducer(producer)
        let subscriber = SubscriberWithBackpressure(
            demands: demands,
            pause: .milliseconds(200),
            completionExpectation: expectation)
        publisher.subscribe(subscriber)
        
        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(producer.callsToStart, 1)
        XCTAssertEqual(producer.callsToPause, demands.count)
        XCTAssertEqual(producer.callsToResume, demands.count - 1)
        XCTAssertEqual(producer.callsToCancel, 0)
        XCTAssertEqual(Array(0..<totalDemand), subscriber.receivedElements)
    }
    
    static var allTests = [
        ("test_correct_backpressure_handling", test_correct_backpressure_handling)
    ]
}
