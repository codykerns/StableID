//
//  StableID.swift
//
//
//  Created by Cody Kerns on 2/10/24.
//

import Foundation
import StoreKit

/// Policy for handling provided IDs during configuration
public enum IDPolicy {
    /// Use stored ID if available (iCloud or local), otherwise use the provided/generated ID
    case preferStored
    /// Always use the provided ID and update storage
    case forceUpdate
}

public class StableID {
    internal static var instance: StableID? = nil

    private static var shared: StableID {
        guard let instance else {
             fatalError("StableID not configured.")
        }
        return instance
    }

    private init(id: String, idGenerator: IDGenerator) {
        self.id = id
        self.idGenerator = idGenerator
    }

    private static var remoteStore = NSUbiquitousKeyValueStore.default
    private static var localStore = UserDefaults(suiteName: Constants.StableID_Key_DefaultsSuiteName)

    public static func configure(id: String? = nil, idGenerator: IDGenerator = StandardGenerator(), policy: IDPolicy = .forceUpdate) {
        guard isConfigured == false else {
            Self.logger.log(type: .error, message: "StableID has already been configured! Call `identify` to change the identifier.")
            return
        }

        Self.logger.log(type: .info, message: "Configuring StableID...")

        // By default, generate a new anonymous identifier that we'll use if there isn't an ID present
        var identifier = idGenerator.generateID()

        if let id {
            // If policy is preferStored, check for stored IDs first
            if policy == .preferStored {
                Self.logger.log(type: .info, message: "ID provided with preferStored policy.")
                identifier = Self.fetchStoredID() ?? id
            } else {
                // forceUpdate policy: always use the provided ID
                identifier = id
                Self.logger.log(type: .info, message: "Identifying with configured ID: \(id)")
            }
        } else {
            Self.logger.log(type: .info, message: "No ID passed to `configure`.")
            identifier = Self.fetchStoredID()  ?? identifier
        }

        let stableID = StableID(id: identifier, idGenerator: idGenerator)
        stableID.persist(identifier: identifier)

        Self.instance = stableID

        Self.logger.log(type: .info, message: "Configured StableID. Current user ID: \(identifier)")

        NotificationCenter.default.addObserver(Self.shared,
                                               selector: #selector(didChangeExternally),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: NSUbiquitousKeyValueStore.default)
    }

    private static let logger = StableIDLogger()

    private var idGenerator: any IDGenerator

    private var id: String

    private var delegate: (any StableIDDelegate)?

    private func setIdentity(value: String) {
        if value != id {

            var adjustedId = value

            if let delegateId = self.delegate?.willChangeID(currentID: self.id, candidateID: value) {
                adjustedId = delegateId
            }

            Self.logger.log(type: .info, message: "Setting StableID to \(adjustedId)")

            Self.shared.id = adjustedId
            self.persist(identifier: adjustedId)

            self.delegate?.didChangeID(newID: adjustedId)
        }
    }

    private func generateID() {
        Self.logger.log(type: .info, message: "Generating new StableID.")

        let newID = self.idGenerator.generateID()
        self.setIdentity(value: newID)
    }

    private static func fetchStoredID() -> String? {
        Self.logger.log(type: .info, message: "Checking iCloud store...")

        if let remoteID = remoteStore.string(forKey: Constants.StableID_Key_Identifier) {
            Self.logger.log(type: .info, message: "Found iCloud ID: \(remoteID)")
            return remoteID
        }

        Self.logger.log(type: .info, message: "No ID available in iCloud. Checking local defaults...")

        if let localID = localStore?.string(forKey: Constants.StableID_Key_Identifier) {
            Self.logger.log(type: .info, message: "Found local ID: \(localID)")
            return localID
        }

        Self.logger.log(type: .info, message: "No stored ID found.")
        return nil
    }

    private func persist(identifier: String) {
        Self.localStore?.set(identifier, forKey: Constants.StableID_Key_Identifier)
        Self.remoteStore.set(identifier, forKey: Constants.StableID_Key_Identifier)
        Self.remoteStore.synchronize()
    }

    @objc
    private func didChangeExternally(_ notification: Notification) {
        if let newId = Self.remoteStore.string(forKey: Constants.StableID_Key_Identifier) {
            if newId != id {
                Self.logger.log(type: .info, message: "Detected new StableID: \(newId)")

                self.setIdentity(value: newId)
            } else {
                // the identifier was updated remotely, but it's the same identifier
                Self.logger.log(type: .info, message: "No change to StableID.")
            }

        } else {
            Self.logger.log(type: .warning, message: "StableID removed from iCloud. Reverting to local value: \(id)")

            // The store was updated, but the id is empty. Reset back to configured identifier
            self.setIdentity(value: id)
        }

    }
}


/// Public methods
extension StableID {
    public static var isConfigured: Bool { instance != nil }

    public static var id: String { return Self.shared.id }

    public static func identify(id: String) {
        Self.shared.setIdentity(value: id)
    }

    public static func generateNewID() {
        Self.shared.generateID()
    }

    public static func set(delegate: any StableIDDelegate) {
        Self.shared.delegate = delegate
    }
    
    public static var hasStoredID: Bool { fetchStoredID() != nil }

    /// Resets the StableID instance. For testing purposes only.
    /// - Warning: This will clear the current StableID instance and require reconfiguration.
    internal static func reset() {
        instance = nil
    }

    /// Fetches the AppTransactionID from the App Store.
    /// The AppTransactionID is a globally unique identifier for each Apple Account that downloads your app.
    /// It remains stable across redownloads, refunds, repurchases, and storefront changes.
    ///
    /// Example usage:
    /// ```swift
    /// let id = try await StableID.fetchAppTransactionID()
    /// StableID.configure(id: id, policy: .preferStored)
    /// ```
    ///
    /// - Returns: The appTransactionID if the transaction is verified
    /// - Throws: An error if the app transaction verification fails
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
    public static func fetchAppTransactionID() async throws -> String {
        let verificationResult = try await AppTransaction.shared

        switch verificationResult {
        case .verified(let appTransaction):
            // StoreKit verified the app transaction
            return appTransaction.appTransactionID
        case .unverified(_, let verificationError):
            // The app transaction didn't pass StoreKit's verification
            throw verificationError
        }
    }
}
