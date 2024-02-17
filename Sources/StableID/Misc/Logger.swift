//
//  Logger.swift
//  
//
//  Created by Cody Kerns on 2/11/24.
//

import Foundation

internal struct StableIDLogger {
    enum LogType {
        case info, warning, error

        var title: String {
            switch self {
            case .info:
                return "ℹ️ INFO:"
            case .warning:
                return "⚠️ WARNING:"
            case .error:
                return "🚨 ERROR:"
            }
        }
    }

    func log(type: LogType, message: String) {
        let message: String = "[StableID] - \(type.title) \(message)"
        print(message)
    }
}
