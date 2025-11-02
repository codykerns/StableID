import XCTest
@testable import StableID

final class StableIDTests: XCTestCase {
    func clearDefaults() {
        guard let defaults = UserDefaults(suiteName: Constants.StableID_Key_DefaultsSuiteName) else { return }

        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            print(key)
            defaults.removeObject(forKey: key)
        }
    }

    override func setUp() {
        super.setUp()

        clearDefaults()
    }

    override func tearDown() {
        super.tearDown()

        StableID.reset()
    }

    func testConfiguring() {
        StableID.configure()
        XCTAssert(StableID.isConfigured == true)
    }

    func testIdentifying() {
        StableID.configure()

        let uuid = UUID().uuidString
        StableID.identify(id: uuid)

        XCTAssert(StableID.id == uuid)
    }

    func testGenerateNewID() {
        StableID.configure()
        let originalID = StableID.id

        StableID.generateNewID()
        let newID = StableID.id

        XCTAssert(originalID != newID)
    }

    func testShortIDLength() {
        StableID.configure(idGenerator: StableID.ShortIDGenerator())

        XCTAssert(StableID.id.count == 8)
    }

    func testPersistenceAcrossReconfigurations() {
        // Configure with a specific ID
        let originalID = "test-persistent-id"
        StableID.configure(id: originalID)
        XCTAssertEqual(StableID.id, originalID)

        // Reset and reconfigure without providing an ID - should retrieve from storage
        StableID.reset()
        StableID.configure()

        XCTAssertEqual(StableID.id, originalID, "ID should persist from local storage")
    }

    func testPreferStoredPolicy() {
        // First, save an ID to storage
        let storedID = "stored-id"
        StableID.configure(id: storedID)

        // Reset and configure with a different ID using preferStored policy
        StableID.reset()
        let newID = "new-id"
        StableID.configure(id: newID, policy: .preferStored)

        // Should use the stored ID, not the new one
        XCTAssertEqual(StableID.id, storedID, "Should prefer stored ID over provided ID")
    }

    func testForceUpdatePolicy() {
        // First, save an ID to storage
        let storedID = "stored-id"
        StableID.configure(id: storedID)

        // Reset and configure with a different ID using forceUpdate policy
        StableID.reset()
        let newID = "new-id"
        StableID.configure(id: newID, policy: .forceUpdate)

        // Should use the new ID, replacing the stored one
        XCTAssertEqual(StableID.id, newID, "Should force update with provided ID")
    }

    func testDelegateCallbacks() {
        class TestDelegate: StableIDDelegate {
            var willChangeCallCount = 0
            var didChangeCallCount = 0
            var lastOldID: String?
            var lastNewID: String?

            func willChangeID(currentID: String, candidateID: String) -> String? {
                willChangeCallCount += 1
                lastOldID = currentID
                return nil
            }

            func didChangeID(newID: String) {
                didChangeCallCount += 1
                lastNewID = newID
            }
        }

        StableID.configure()
        let originalID = StableID.id

        let delegate = TestDelegate()
        StableID.set(delegate: delegate)

        let newID = "changed-id"
        StableID.identify(id: newID)

        XCTAssertEqual(delegate.willChangeCallCount, 1, "willChangeID should be called once")
        XCTAssertEqual(delegate.didChangeCallCount, 1, "didChangeID should be called once")
        XCTAssertEqual(delegate.lastOldID, originalID, "Should pass old ID to willChangeID")
        XCTAssertEqual(delegate.lastNewID, newID, "Should pass new ID to didChangeID")
    }

    func testDoubleConfigurationPrevented() {
        StableID.configure()
        XCTAssertTrue(StableID.isConfigured)

        // Attempting to configure again should be prevented
        let firstID = StableID.id
        StableID.configure(id: "should-not-change")

        XCTAssertEqual(StableID.id, firstID, "ID should not change on second configure")
    }

    func testHasStoredID() {
        // Initially should have no stored ID
        XCTAssertFalse(StableID.hasStoredID, "Should have no stored ID initially")

        // After configuring, should have stored ID
        StableID.configure(id: "test-id")
        XCTAssertTrue(StableID.hasStoredID, "Should have stored ID after configuration")

        // After reset, should still have stored ID (persisted in UserDefaults)
        StableID.reset()
        XCTAssertTrue(StableID.hasStoredID, "Should still have stored ID after reset")
    }
}
