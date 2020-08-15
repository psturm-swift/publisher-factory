import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ClosureProducerTests.allTests),
        testCase(LockableTests.allTests),
        testCase(ProducerTests.allTests),
    ]
}
#endif
