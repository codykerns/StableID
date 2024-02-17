//
//  Delegate.swift
//
//
//  Created by Cody Kerns on 2/13/24.
//

import Foundation

public protocol StableIDDelegate {
    /// Called when StableID is about to change the identified user ID.
    /// Return `nil` to prevent the change.
    func willChangeID(currentID: String, candidateID: String) -> String?

    /// Called after StableID changes the identified user ID.
    func didChangeID(newID: String)
}

extension StableIDPlugin {
    public static func simple(didChangeID: ((String) -> Void)) -> BasicPlugin {
        return StableID.SimplePlugin(didChangeID: didChangeID)
    }
}
