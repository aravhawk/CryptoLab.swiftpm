//
//  CryptoLabApp.swift
//  CryptoLab
//
//  Created by Arav Jain on 1/8/25.
//

import SwiftUI

@main
struct CryptoLabApp: App {
    @StateObject private var cryptoModel = CryptoModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cryptoModel)
                .preferredColorScheme(.dark) // Using dark mode for a techy asthetic to complement the topic of cryptocurrency
        }
    }
}
