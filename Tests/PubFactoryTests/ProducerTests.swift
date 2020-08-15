/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import XCTest
import Combine
@testable import PubFactory

final class ProducerTests: XCTestCase {
    func test_proxy_forwards_values() {
        let testValues = [4, 0, 10]
        let testCompletions: [Subscribers.Completion<TestError>]
            = [.finished, .finished, .failure(TestError(id: 3)), .failure(TestError(id: 0))]

        let testDelegate = TestProxyDelegate<Int, TestError>()
        let proxy = Proxy(delegate: testDelegate)
        
        testValues.forEach { proxy.receive($0) }
        XCTAssertEqual(testDelegate.receivedValues, testValues)
        
        testCompletions.forEach { proxy.receive(completion: $0) }
        XCTAssertEqual(testDelegate.receivedCompletions, testCompletions)
    }
    
    func test_if_proxy_has_only_a_weak_reference_on_its_delegate() {
        let testDelegate = TestProxyDelegate<Int, TestError>()
        var forwarder: TestProxyDelegateForwarder<Int, TestError>? = .init(delegate: testDelegate)
        let proxy = Proxy(delegate: forwarder!)

        proxy.receive(4)
        XCTAssertEqual(testDelegate.receivedValues, [4])
        proxy.receive(completion: .finished)
        XCTAssertEqual(testDelegate.receivedCompletions, [.finished])
        
        forwarder = nil // Proxy should have a weak reference on forwarder
        
        proxy.receive(10)
        XCTAssertEqual(testDelegate.receivedValues, [4])
        proxy.receive(completion: .failure(TestError(id: 8)))
        XCTAssertEqual(testDelegate.receivedCompletions, [.finished])
    }
    
    static var allTests = [
        ("test_proxy_forwards_values", test_proxy_forwards_values)
    ]
}

fileprivate struct TestError: Error {
    let id: Int
}

extension TestError: Equatable {}

fileprivate class TestProxyDelegate<T, F: Error>: ProxyDelegate {
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

fileprivate class TestProxyDelegateForwarder<T, F: Error>: ProxyDelegate {
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
