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
        let demands = [4,2,4]
        let totalDemand = demands.reduce(0, +)
        let expectation = XCTestExpectation(description: "Publisher terminates")
        
        let producer = ProducerForBackpressureTests()
        let publisher = WithProducer(producer).prefix(totalDemand)
        let subscriber = TestSubscriberWithBackpressure(demands: demands, pause: .milliseconds(500), expectation: expectation)
        publisher.subscribe(subscriber)
        
        wait(for: [expectation], timeout: 5)
        subscriber.cancel()
        
        var counter = 0
        var phase = 0
        var expectedItems: [ProducerForBackpressureTests.State] = []
        for demand in demands {
            for _ in 0..<demand {
                expectedItems.append(.init(pauseCount: phase, resumeCount: phase, current: counter))
                counter += 1
            }
            phase += 1
        }
        
        XCTAssertEqual(expectedItems, subscriber.receivedElements)
    }
    
    static var allTests = [
        ("test_correct_backpressure_handling", test_correct_backpressure_handling)
    ]
}


extension NSLock: Lockable {}

fileprivate final class ProducerForBackpressureTests: Producer {
    typealias Output = State
    typealias Failure = Never

    struct State: Equatable {
        var pauseCount: Int = 0
        var resumeCount: Int = 0
        var current: Int = 0
    }
    
    private var lock = NSLock()
    private var state = State()
    private var thread: Thread? = nil
    
    func start(with proxy: Proxy<State, Never>) {
        self.thread = Thread { [weak self] in
            while !Thread.current.isCancelled {
                if let self = self, self.state.pauseCount == self.state.resumeCount {
                    proxy.receive(self.state)
                    self.lock.synchronize {
                        self.state.current += 1
                    }
                }
            }
        }
        self.thread?.start()
    }
    
    func pause() {
        self.lock.synchronize {
            state.pauseCount += 1
        }
    }
    
    func resume() {
        self.lock.synchronize {
            state.resumeCount += 1
        }
    }
    
    func cancel() {
        self.thread?.cancel()
    }
}

fileprivate final class TestSubscriberWithBackpressure: Subscriber {
    typealias Input = ProducerForBackpressureTests.Output
    typealias Failure = Never
    let pause: DispatchTimeInterval
    var subscription: Subscription?
    var receivedElements: [Input] = []
    var remainingDemand: [Int]
    var receivedDemand: Int
    var currentDemand: Int
    let expectation: XCTestExpectation
    
    init(demands: [Int], pause: DispatchTimeInterval, expectation: XCTestExpectation) {
        self.remainingDemand = demands
        self.pause = pause
        self.currentDemand = 0
        self.receivedDemand = 0
        self.expectation = expectation
    }

    private func requestNextDemand() {
        guard let currentDemand = remainingDemand.first else { return }
        self.currentDemand = currentDemand
        remainingDemand = Array(remainingDemand.dropFirst())
        subscription?.request(.max(currentDemand))
    }
    
    func receive(subscription: Subscription) {
        self.subscription = subscription
        requestNextDemand()
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        receivedElements.append(input)
        currentDemand -= 1
        if currentDemand == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
                self.requestNextDemand()
            }
        }
        return .none
    }
    
    func receive(completion: Subscribers.Completion<Never>) {
        expectation.fulfill()
    }
    
    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
}
