/*
 Copyright 2020 Patrick Sturm

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation
import Combine

public protocol Context {
    var paused: Bool { get }
    var cancelled: Bool { get }
    func waitIfPaused()
}

final class ClosureProducerWithContext<O, F: Error>: Producer {
    typealias Output = O
    typealias Failure = F
    typealias Closure = (Proxy<O, F>, Context)->Void
    
    private let closure: Closure
    private let state = ProducerStateControl()
    private var thread: Thread? = nil
    
    init(_ closure: @escaping Closure) {
        self.closure = closure
    }
    
    func start(with proxy: Proxy<O, F>) {
        let thread = Thread { [weak self] in
            guard let closure = self?.closure else { return }
            guard let state = self?.state else { return }
            closure(proxy, state)
        }
        self.thread = thread
        thread.start()
    }
    
    func pause() {
        state.pause()
    }
    
    func resume() {
        state.resume()
    }

    func cancel() {
        state.cancel()
    }
}

extension ClosureProducerWithContext {
    final class ProducerStateControl: Context {
        enum State {
            case running
            case cancelled
            case paused
        }
        
        private var condition = NSCondition()
        private var state: State = .running
        
        var paused: Bool {
            condition.synchronize {
                return state == .paused
            }
        }
        
        var cancelled: Bool {
            condition.synchronize {
                return state == .cancelled
            }
        }
        
        func pause() {
            condition.synchronize {
                guard state == .running else { return }
                state = .paused
            }
        }
        
        func cancel() {
            condition.synchronize {
                guard state != .cancelled else { return }
                state = .cancelled
                condition.signal()
            }
        }
        
        func resume() {
            condition.synchronize {
                guard state == .paused else { return }
                state = .running
                condition.signal()
            }
        }
        
        func waitIfPaused() {
            condition.synchronize {
                while state == .paused {
                    condition.wait()
                }
            }
        }
    }
}
