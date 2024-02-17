import XCTest
@testable import StableID

final class StableIDTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }

    func clearDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }

    func testConfiguring() {
        clearDefaults()

        StableID.configure()
    }

    func testDelegate() {
        clearDefaults()
        
        StableID.configure()

        let uuid = UUID().uuidString

        StableID.identify(id: uuid)
    }

}
