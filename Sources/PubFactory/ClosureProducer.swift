/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation
import Combine

class ClosureProducer<O, F: Error>: Producer {
    typealias Output = O
    typealias Failure = F
    
    private let closure: (Proxy<Output, Failure>)->AnyCancellable
    private var cancellable: AnyCancellable? = nil
    
    init(_ closure: @escaping (Proxy<Output, Failure>)->AnyCancellable) {
        self.closure = closure
    }
    
    func start(with proxy: Proxy<Output, Failure>) {
        self.cancellable = closure(proxy)
    }
    
    func pause() {}
    func resume() {}
    
    func cancel() {
        self.cancellable?.cancel()
    }
}
