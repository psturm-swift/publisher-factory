/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation
import Combine

/**
 A publisher that produces zero or more elements and then eventually  finishes or fails.
 */
public struct Create<T, F: Error>: Publisher {
    public typealias Output = T
    public typealias Failure = F
    
    private let internalPublisher: AnyPublisher<T,F>
    
    /**
     Creates a publisher that invokes a closure to start an asynchronous operation which emits zero or more elements and then eventually finishs or fails.
     - Parameter closure: A closure that gets a proxy and returns a cancellable. The closure is not allowed to block. It should start an asynchronous task which emits zero or more elements and then eventually finishs or fails the stream. It returns a cancellable to stop the asynchronous operation if the subscription is cancelled.
     - Parameter proxy: A wrapper around the subscriber.
     
     ```
     let publisher =
         Create<Data?, Error> { subscriber in
             let task = URLSession.shared.dataTask(with: url) { dataOrNil, _, errorOrNil in

             if let error = errorOrNil {
                 subscriber.receive(completion: .failure(error))
             }
             else {
                 subscriber.receive(dataOrNil)
                 subscriber.receive(completion: .finished)
             }

             task.resume()
             return AnyCancellable { task.cancel() }
         }
     ```
     */
    public init(closure: @escaping (_ proxy: Proxy<T, F>)->AnyCancellable) {
        self.internalPublisher = WithProducer(ClosureProducer(closure)).eraseToAnyPublisher()
    }
    
    /**
     Creates a publisher that invokes a closure which emits zero or more elements and then eventually finishs or fails. The closure might be blocking.
        - Parameter closure:A closure that gets a proxy and a context. It emits zero or more elements and then eventually finishs or fails the stream. It can use the context to determine if it should pause emitting elements or if it should terminate.
     - Parameter proxy: A wrapper around the subscriber.
     - Parameter context: A context that provides the status of the publisher
     .
     ```
     let publisher =
        Create<Int, Never> { subscriber, context in
            var i = 0
            while !context.cancelled {
                subscriber.receive(i)
                i += 1
            }
        }
     ```
     */
    public init(closure: @escaping (_ proxy: Proxy<T, F>, _ context: Context)->Void) {
        self.internalPublisher = WithProducer(ClosureProducerWithContext(closure)).eraseToAnyPublisher()
    }

    public func receive<S>(subscriber: S)
        where S : Subscriber, Failure == S.Failure, Output == S.Input
    {
        internalPublisher.receive(subscriber: subscriber)
    }
}
