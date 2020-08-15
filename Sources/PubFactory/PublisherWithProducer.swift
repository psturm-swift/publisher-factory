/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation
import Combine

public struct PublisherWithProducer<P: Producer>: Publisher {
    public typealias ProducerType = P
    public typealias Output = P.Output
    public typealias Failure = P.Failure
    
    private let producer: ProducerType
    
    public init(_ producer: ProducerType) {
        self.producer = producer
    }
    
    public func receive<S>(subscriber: S)
        where S : Subscriber, Failure == S.Failure, Output == S.Input
    {
        let subscription = Subscription(subscriber: subscriber, producer: self.producer)
        subscriber.receive(subscription: subscription)
    }
}

private extension PublisherWithProducer {
    class Subscription<S: Subscriber>: Combine.Subscription
        where S.Input == Output, S.Failure == Failure
    {
        typealias Output = ProducerType.Output
        typealias Failure = ProducerType.Failure
        typealias Subscriber = S
        
        private enum ProducerState {
            case initialized
            case running
            case paused
            case finished
        }
        
        private let lock = NSRecursiveLock()
        private var producer: ProducerType? = nil
        private var totalDemand: Subscribers.Demand = .none
        private var subscriber: Subscriber? = nil
        private var producerState: ProducerState = .initialized
        
        init(subscriber: Subscriber, producer: ProducerType) {
            self.producer = producer
            self.subscriber = subscriber
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.synchronize {
                self.totalDemand += demand
                guard producerState != .running else { return }
                guard self.totalDemand > .none else { return }
                switch producerState {
                case .initialized:
                    producerState = .running
                    producer?.start(with: Proxy(delegate: self))
                case .paused:
                    producerState = .running
                    producer?.resume()
                default: break
                }
            }
        }
        
        func cancel() {
            lock.synchronize {
                self.subscriber = nil
                self.totalDemand = .none
                self.producer?.cancel()
                self.producer = nil
                self.producerState = .finished
            }
        }
    }
}

extension PublisherWithProducer.Subscription: ProxyDelegate {
    func receive(_ input: Output) {
        lock.synchronize {
            guard self.totalDemand > .none else { return }
            guard let subscriber = self.subscriber else { return }
            self.totalDemand -= 1
            self.totalDemand += subscriber.receive(input)
            if self.totalDemand == .none && self.producerState == .running {
                self.producerState = .paused
                self.producer?.pause()
            }
        }
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        lock.synchronize {
            guard let subscriber = self.subscriber else { return }
            self.subscriber = nil
            self.totalDemand = .none
            self.producer = nil
            subscriber.receive(completion: completion)
        }
    }
}
