/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation
import Combine
import XCTest

@testable import PubFactory

class TestProxyDelegate<T, F: Error>: ProxyDelegate {
    typealias Output = T
    typealias Failure = F

    var receivedValues: [Output] = []
    var receivedCompletions: [Subscribers.Completion<F>] = []
    
    func receive(_ value: Output) {
        receivedValues.append(value)
    }
    
    func receive(completion: Subscribers.Completion<F>) {
        receivedCompletions.append(completion)
    }
}

class TestProxyDelegateForwarder<T, F: Error>: ProxyDelegate {
    typealias Output = T
    typealias Failure = F

    let delegate: TestProxyDelegate<T, F>
    
    init(delegate: TestProxyDelegate<T, F>) {
        self.delegate = delegate
    }
    
    func receive(_ value: Output) {
        delegate.receive(value)
    }
    
    func receive(completion: Subscribers.Completion<F>) {
        delegate.receive(completion: completion)
    }
}


struct TestError: Error {
    let id: Int
}

extension TestError: Equatable {}

final class TestCountingProducer: Producer {
    typealias Output = Int
    typealias Failure = Never

    var lock = NSLock()
    var thread: Thread? = nil
    var callsToStart: Int = 0
    var callsToPause: Int = 0
    var callsToResume: Int = 0
    var callsToCancel: Int = 0
    var counter: Int = 0
    let maxCounter: Int
    
    init(_ maxCounter: Int) {
        self.maxCounter = maxCounter
    }
    
    func start(with proxy: Proxy<Int, Never>) {
        callsToStart += 1
        thread = Thread { [weak self] in
            while !Thread.current.isCancelled {
                guard let this = self else { return }
                guard this.counter < this.maxCounter else {
                    proxy.receive(completion: .finished)
                    return
                }
                if !this.isPaused {
                    proxy.receive(this.counter)
                    this.counter += 1
                }
            }
        }
        thread?.start()
    }
    
    private var isPaused: Bool {
        lock.synchronize {
            callsToPause > callsToResume
        }
    }
    
    func pause() {
        lock.synchronize {
            callsToPause += 1
        }
    }
    
    func resume() {
        lock.synchronize {
            callsToResume += 1
        }
    }
    
    func cancel() {
        callsToCancel += 1
        self.thread?.cancel()
    }
}

extension NSLock: Lockable {}

final class TestSubscriberWithBackpressure: Subscriber {
    typealias Input = TestCountingProducer.Output
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
