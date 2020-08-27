# PubFactory
Creating a custom publisher with Apple's Combine framework is a task that involves many lines of code. But the code between custom publishers is often very similar. In Combine only the class `Future` allows to build a publisher just from a simple closure. Unfortunately, `Future` does not allow to cancel the task within that closure. Furthermode, `Future` allows exactly one output item only.

`PubFactory` provides the class `Create` to build custom publishers which are fully cancellable and which can emit a stream of items.

## Concept
Each asynchronous call can be easily transformed into a custom publisher with `PubFactory.Create`. In its simplest form `PubFactory.Create` is initialized with a closure. The closure has one parameter (subscriber) that gives the closure the ability to send out items and a completion (finished or failure) to the connected subscriber down-streams. The only task of the closure is to start an asynchronous operation and to return a cancellable that is able to stop this operation. The class `Create` requires two generics: The output type of the publisher and its error type.

```swift
let publisher = Create<Int, Never> { subscriber in
    // Start asynchronous operation
    return AnyCancellable {
        // Action to stop asynchronous operation
    }
}
```

The asynchronous operation can use the `subscriber` object to notify the subscriber down-streams. The following code sends the integer sequence 4, 2, 7 to the connected subscriber. At the end it completes the stream without failure.

```swift
subscriber.receive(4)
subscriber.receive(2)
subscriber.receive(7)
subscriber.receive(completion: .finished)
```

## Example: `URLSession`
Let's look at an example. We implement our own version of `URLSession.dataTaskPublisher` by using `PubFactory.Create`:

```swift
extension URLSession {
    func myDataTaskPublisher(for url: URL) -> Create<Data?, Error> {
        Create<Data?, Error> { subscriber in
            let task = URLSession.shared.dataTask(with: url) { dataOrNil, _, errorOrNil in
                if let error = errorOrNil {
                    subscriber.receive(completion: .failure(error))
                }
                else {
                    subscriber.receive(dataOrNil)
                    subscriber.receive(completion: .finished)
                }
            }
            task.resume()
            return AnyCancellable { task.cancel() }
        }
    }
}
```

In this example the closure creates and starts a `URLSession.dataTask` to load a web site. The data task itself has a completion closure that is called if the web site content has been loaded or if an error occured. In case of error, the closure sends a failure to the subscriber by calling:

```swift
subscriber.receive(completion: .failure(error))
```

If no error occured, it sends the data to the subscriber and completes the stream immediately afterwards:

```swift
subscriber.receive(dataOrNil)
subscriber.receive(completion: .finished)
```

The closure returns a cancellable that stops the task as soon the subscription is cancelled:

```swift
return AnyCancellable { task.cancel() }
```

In this particular case you could use `Future` from the Combine framework instead. The disadvantage of using `Future` is, that the data task cannot be cancelled.

```swift
Future<Data?, Error> { subscriber in
    let task = URLSession.shared.dataTask(with: url) { dataOrNil, _, errorOrNil in
        if let error = errorOrNil {
            subscriber(.failure(error))
        }
        else {
            subscriber(.success(dataOrNil))
        }
    }
    task.resume()
}
```

## Example: Number generator
In the following example we define a publisher that sends incrementally ascending integer numbers starting with 0.

```swift
let numberGenerator = Create<Int, Never> { subscriber in
    thread = Thread {
        var i = 0
        while !Thread.current.isCancelled {
            subscriber.receive(i)
            i += 1
        }
    }
    thread?.start()
    return AnyCancellable { thread?.cancel() }
}
```

To do so the closure starts its own thread which increments the variable `i`. With each change the content of `i` is send to `subscriber`. This process continues until the thread is cancelled. Therefore the closure returns a `AnyCancellable` that will stop the thread if the subscription has been cancelled.

It is very important that the closure does not block. If it would be blocking then the Cancellable which should stop the task inside the closure would never be constructed. Thus the following code is **invalid**:

```swift
let numberGenerator = Create<Int, Never> { subscriber in
    var isCancelled = false
    var i = 0
    while !isCancelled {
        subscriber.receive(i)
        i += 1
    }
    return AnyCancellable { isCancelled = true }
}
```

## Backpressure with `Create`
Combine has backpressure handling integrated. `Create` provides basic backpressure handling as well. If the demand of the subscriber is `.none` then all items sent by `subscriber.receive(:)` are simply ignored until the demand is increased again.

## `Create` with Context
There is a second possibility to create a publisher with `Create`. It is made for use cases like the number generator. A closure with two parameters is used. The first parameter is a `subscriber` and the second parameter is a `context`. This closure does not return a cancellable as it is expected that the closure stops itself based on the status of the `context`:

```swift
let publisher = Create<Int, Never> { subscriber, context in
    var i = 0
    while !context.cancelled {
        subscriber.receive(i)
        i += 1
    }
}
```

The `context` provides the information about the state of the subscription:

```swift
protocol Context {
    var paused: Bool { get }
    var cancelled: Bool { get }
    func waitIfPaused()
}
```

It also provides backpressure support. In the case the subscriber's demand if `.none`, the number generator can easily be stopped temporarily by just adding one more command:

```swift
let publisher = Create<Int, Never> { subscriber, context in
    var i = 0
    while !context.cancelled {
        context.waitIfPaused()
        subscriber.receive(i)
        i += 1
    }
}
```

## Usage
The package can be installed by using the Swift Package Manager.

## License
MIT License

Copyright 2020 Patrick Sturm

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE
