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
        guard let defaults = UserDefaults(suiteName: Constants.StableID_Key_DefaultsSuiteName) else { return }
        
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            print(key)
            defaults.removeObject(forKey: key)
        }
    }

    func testConfiguring() {
        clearDefaults()

        StableID.configure()
        XCTAssert(StableID.isConfigured == true)
    }

    func testIdentifying() {
        clearDefaults()
        
        StableID.configure()

        let uuid = UUID().uuidString
        StableID.identify(id: uuid)

        XCTAssert(StableID.id == uuid)
    }

    func testGenerateNewID() {
        clearDefaults()
        
        StableID.configure()
        let originalID = StableID.id

        StableID.generateNewID()
        let newID = StableID.id

        XCTAssert(originalID != newID)
    }

    func testShortIDLength() {
        clearDefaults()

        StableID.configure(idGenerator: StableID.ShortIDGenerator())

        XCTAssert(StableID.id.count == 8)
    }
}
