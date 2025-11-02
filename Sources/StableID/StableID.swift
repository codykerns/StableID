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

    /// Configures StableID with an optional user identifier.
    ///
    /// This method initializes the StableID system and must be called before accessing any other StableID methods.
    /// It can only be called once per app session - subsequent calls will be ignored.
    ///
    /// - Parameters:
    ///   - id: An optional identifier to use. If nil, will use a stored ID (from iCloud or local storage) or generate a new one.
    ///   - idGenerator: The generator to use for creating new IDs. Defaults to `StandardGenerator()` which produces UUIDs.
    ///   - policy: Controls how the provided ID is handled. Defaults to `.forceUpdate`.
    ///     - `.forceUpdate`: Always uses the provided ID and updates storage
    ///     - `.preferStored`: Uses stored ID if available, otherwise uses the provided ID
    ///
    /// Example usage:
    /// ```swift
    /// // Basic configuration with auto-generated ID
    /// StableID.configure()
    ///
    /// // With AppTransactionID
    /// if let id = try? await StableID.fetchAppTransactionID() {
    ///     StableID.configure(id: id, policy: .preferStored)
    /// } else {
    ///     StableID.configure()
    /// }
    /// ```
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
                Self.logger.log(type: .info, message: "Detected new StableID in iCloud: \(newId)")

                self.setIdentity(value: newId)
            } else {
                // the identifier was updated remotely, but it's the same identifier
                Self.logger.log(type: .info, message: "StableID was updated in iCloud, but it's the same identifier that's already configured.")
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
    /// Returns whether StableID has been configured.
    ///
    /// Check this property before calling `configure()` to avoid double-configuration errors.
    ///
    /// Example usage:
    /// ```swift
    /// if !StableID.isConfigured {
    ///     StableID.configure()
    /// }
    /// ```
    public static var isConfigured: Bool { instance != nil }

    /// The current stable identifier.
    ///
    /// This property returns the active user ID. It persists across app launches and syncs via iCloud.
    ///
    /// Example usage:
    /// ```swift
    /// let userID = StableID.id
    /// Purchases.configure(withAPIKey: "key", appUserID: userID)
    /// ```
    ///
    /// - Warning: Accessing this property before calling `configure()` will result in a fatal error.
    public static var id: String { return Self.shared.id }

    /// Changes the current identifier to a new value.
    ///
    /// Use this method to update the user's identifier, for example when a user logs in with their account.
    /// The new ID will be persisted to both local storage and iCloud, and any configured delegates will be notified.
    ///
    /// - Parameter id: The new identifier to use.
    ///
    /// Example usage:
    /// ```swift
    /// // When user logs in
    /// StableID.identify(id: "user-account-123")
    ///
    /// // Update RevenueCat
    /// Purchases.shared.logIn("user-account-123") { _, _, _ in }
    /// ```
    ///
    /// - Warning: Calling this method before `configure()` will result in a fatal error.
    public static func identify(id: String) {
        Self.shared.setIdentity(value: id)
    }

    /// Generates and sets a new random identifier.
    ///
    /// This method creates a new ID using the configured ID generator and updates both local and iCloud storage.
    /// Use this when you need to create a new anonymous user, for example after a user logs out.
    ///
    /// Example usage:
    /// ```swift
    /// // When user logs out
    /// StableID.generateNewID()
    ///
    /// // Update RevenueCat with new anonymous ID
    /// Purchases.shared.logOut { _ in
    ///     Purchases.shared.logIn(StableID.id) { _, _, _ in }
    /// }
    /// ```
    ///
    /// - Warning: Calling this method before `configure()` will result in a fatal error.
    public static func generateNewID() {
        Self.shared.generateID()
    }

    /// Sets a delegate to receive notifications when the ID changes.
    ///
    /// The delegate receives callbacks before and after ID changes, allowing you to validate
    /// or respond to ID updates from any source (manual, iCloud sync, or generation).
    ///
    /// - Parameter delegate: An object conforming to `StableIDDelegate`.
    ///
    /// Example usage:
    /// ```swift
    /// class MyDelegate: StableIDDelegate {
    ///     func willChangeID(currentID: String, candidateID: String) -> String? {
    ///         // Optional: validate or modify the candidate ID
    ///         return nil
    ///     }
    ///
    ///     func didChangeID(newID: String) {
    ///         // Sync with your backend or RevenueCat
    ///         Purchases.shared.logIn(newID) { _, _, _ in }
    ///     }
    /// }
    ///
    /// StableID.set(delegate: MyDelegate())
    /// ```
    ///
    /// - Warning: Calling this method before `configure()` will result in a fatal error.
    public static func set(delegate: any StableIDDelegate) {
        Self.shared.delegate = delegate
    }

    /// Returns whether an ID is stored in iCloud or local storage.
    ///
    /// Use this property to determine if you need to fetch a new ID (like AppTransactionID)
    /// or if you can use the existing stored value.
    ///
    /// Example usage:
    /// ```swift
    /// if StableID.hasStoredID {
    ///     StableID.configure()
    /// } else {
    ///     // Fetch AppTransactionID only if needed
    ///     if let id = try? await StableID.fetchAppTransactionID() {
    ///         StableID.configure(id: id)
    ///     }
    /// }
    /// ```
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
