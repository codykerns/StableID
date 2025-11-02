//
//  Delegate.swift
//
//
//  Created by Cody Kerns on 2/13/24.
//

import Foundation

public protocol StableIDDelegate {
    /// Called when StableID is about to change the identified user ID.
    ///
    /// Use this to validate or modify the candidate ID before it's set.
    ///
    /// - Parameters:
    ///   - currentID: The current user ID
    ///   - candidateID: The proposed new user ID
    /// - Returns: An adjusted ID to use instead, or `nil` to use the candidate ID as-is
    func willChangeID(currentID: String, candidateID: String) -> String?

    /// Called after StableID changes the identified user ID.
    ///
    /// Use this to sync the new ID with other services like RevenueCat.
    ///
    /// - Parameter newID: The new user ID that was set
    func didChangeID(newID: String)
}
