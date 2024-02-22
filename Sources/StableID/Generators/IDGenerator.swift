//
//  IDGenerator.swift
//
//
//  Created by Cody Kerns on 2/17/24.
//

import Foundation

public protocol IDGenerator {
    func generateID() -> String
}

extension StableID {
    public class StandardGenerator: IDGenerator {
        public init() { }
        
        public func generateID() -> String {
            return UUID().uuidString
        }
    }

    public class ShortIDGenerator: IDGenerator {
        public init() { }

        public func generateID() -> String {
            let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

            return String((0..<8).compactMap { _ in
                letters.randomElement()
            })
        }
    }
}
