//
//  StableID.swift
//
//
//  Created by Cody Kerns on 2/10/24.
//

import Foundation

public class StableID {
    internal static var _stableID: StableID? = nil

    private static var shared: StableID {
        guard let _stableID else {
             fatalError("StableID not configured.")
        }
        return _stableID
    }

    private init(_id: String, _idGenerator: IDGenerator) {
        self._id = _id
        self._idGenerator = _idGenerator
    }

    private static var _remoteStore = NSUbiquitousKeyValueStore.default
    private static var _localStore = UserDefaults(suiteName: Constants.StableID_Key_DefaultsSuiteName)

    public static func configure(id: String? = nil, idGenerator: IDGenerator = StandardGenerator()) {
        guard isConfigured == false else {
            self.logger.log(type: .error, message: "StableID has already been configured! Call `identify` to change the identifier.")
            return
        }

        self.logger.log(type: .info, message: "Configuring StableID...")

        // By default, generate a new anonymous identifier
        var identifier = idGenerator.generateID()

        if let id {
            // if an identifier is provided in the configure method, identify with it
            identifier = id
            self.logger.log(type: .info, message: "Identifying with configured ID: \(id)")
        } else {
            self.logger.log(type: .info, message: "No ID passed to `configure`. Checking iCloud store...")

            if let remoteID = Self._remoteStore.string(forKey: Constants.StableID_Key_Identifier) {
                // if an identifier exists in iCloud, use that
                identifier = remoteID
                self.logger.log(type: .info, message: "Configuring with iCloud ID: \(remoteID)")
            } else {
                self.logger.log(type: .info, message: "No ID available in iCloud. Checking local defaults...")

                if let localID = Self._localStore?.string(forKey: Constants.StableID_Key_Identifier) {
                    // if an identifier only exists locally, use that
                    identifier = localID
                    self.logger.log(type: .info, message: "Configuring with local ID: \(localID)")
                } else {
                    self.logger.log(type: .info, message: "No available identifier. Generating new unique user identifier...")
                    self.generateNewID()
                }
            }
        }

        _stableID = StableID(_id: identifier, _idGenerator: idGenerator)
        
        self.logger.log(type: .info, message: "Configured StableID. Current user ID: \(identifier)")

        NotificationCenter.default.addObserver(Self.shared,
                                               selector: #selector(didChangeExternally),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: NSUbiquitousKeyValueStore.default)
    }

    private static let logger = StableIDLogger()

    private var _idGenerator: any IDGenerator

    private var _id: String

    private var delegate: (any StableIDDelegate)?

    private func setIdentity(value: String) {
        if value != _id {

            var adjustedId = value

            if let delegateId = self.delegate?.willChangeID(currentID: self._id, candidateID: value) {
                adjustedId = delegateId
            }

            Self.logger.log(type: .info, message: "Setting StableID to \(adjustedId)")

            Self.shared._id = adjustedId
            self.setLocal(key: Constants.StableID_Key_Identifier, value: adjustedId)
            self.setRemote(key: Constants.StableID_Key_Identifier, value: adjustedId)

            self.delegate?.didChangeID(newID: adjustedId)
        }
    }

    private func generateID() {
        Self.logger.log(type: .info, message: "Generating new StableID.")

        let newID = self._idGenerator.generateID()
        self.setIdentity(value: newID)
    }

    private func setLocal(key: String, value: String) {
        Self._localStore?.set(value, forKey: key)
    }

    private func setRemote(key: String, value: String) {
        Self._remoteStore.set(value, forKey: key)
        Self._remoteStore.synchronize()
    }

    @objc
    private func didChangeExternally(_ notification: Notification) {
        if let newId = Self._remoteStore.string(forKey: Constants.StableID_Key_Identifier) {
            if newId != _id {
                Self.logger.log(type: .info, message: "Detected new StableID: \(newId)")

                self.setIdentity(value: newId)
            } else {
                // the identifier was updated remotely, but it's the same identifier
                Self.logger.log(type: .info, message: "No change to StableID.")
            }

        } else {
            Self.logger.log(type: .warning, message: "StableID removed from iCloud. Reverting to local value: \(_id)")

            // The store was updated, but the id is empty. Reset back to configured identifier
            self.setIdentity(value: _id)
        }

    }
}


/// Public methods
extension StableID {
    public static var isConfigured: Bool { _stableID != nil }

    public static var id: String { return Self.shared._id }

    public static func identify(id: String) {
        Self.shared.setIdentity(value: id)
    }

    public static func generateNewID() {
        Self.shared.generateID()
    }

    public static func set(delegate: any StableIDDelegate) {
        Self.shared.delegate = delegate
    }
}
