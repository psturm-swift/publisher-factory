import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CreateTests.allTests),
        testCase(LockableTests.allTests),
        testCase(ProducerTests.allTests),
    ]
}
#endif
