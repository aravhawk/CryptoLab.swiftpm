//
//  BiometricAuthenticator.swift
//  CryptoLab
//
//  Created by Arav Jain on 2/21/25.
//

import LocalAuthentication
import SwiftUI

// Credit to https://www.hackingwithswift.com/books/ios-swiftui/using-touch-id-and-face-id-with-swiftui for the guide to LocalAuthentication

struct BiometricAuthenticator {
    static func authenticateUser(reason: String = "",
                                 onSuccess: @escaping () -> Void,
                                 onFailure: @escaping (Error?) -> Void) {
        let context = LAContext()
        var authError: NSError?
        
        // Check if biometrics (Touch ID / Face ID) or device passcode is available
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evaluateError in
                if success {
                    DispatchQueue.main.async {
                        onSuccess()
                    }
                } else {
                    DispatchQueue.main.async {
                        onFailure(evaluateError)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                // If we cannot evaluate policy, consider how you want to handle that scenario
                onFailure(authError)
            }
        }
    }
}
