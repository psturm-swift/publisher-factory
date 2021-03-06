/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation
import Combine

public protocol Producer: Cancellable {
    associatedtype Output
    associatedtype Failure: Error
    
    func start(with proxy: Proxy<Output, Failure>)
    func pause()
    func resume()
}

protocol ProxyDelegate: class {
    associatedtype Output
    associatedtype Failure: Error
    
    func receive(_ value: Output)
    func receive(completion: Subscribers.Completion<Failure>)
}

/**
 `Proxy` forwards its receive calls to the connected subscriber. It is used inside the `Create` closures.
 */
public struct Proxy<O, F: Error> {
    public typealias Output = O
    public typealias Failure = F
    
    private let forwardValue: (Output)->Void
    private let forwardCompletion: (Subscribers.Completion<Failure>)->Void
    
    init<P: ProxyDelegate>(delegate: P) where P.Output==Output, P.Failure==Failure {
        forwardValue = { [weak delegate] in delegate?.receive($0) }
        forwardCompletion = { [weak delegate] in delegate?.receive(completion: $0) }
    }
    
    /**
     Sends a new element to the connected subscriber.
     
     - Parameter value: Value that is send to the connected subscriber
     */
    public func receive(_ value: Output) {
        forwardValue(value)
    }
    
    /**
     Tells the subscriber that the producer has finished or failed
     
     - Parameter completion: Completion that is send to the subscriber.
     */
    public func receive(completion: Subscribers.Completion<Failure>) {
        forwardCompletion(completion)
    }
}
