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
}
