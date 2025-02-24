//
//  WalletGenerationView.swift
//  CryptoLab
//
//  Created by Arav Jain on 1/26/25.
//

import SwiftUI
import Security
import CryptoKit

struct WalletGenerationView: View {
    // Displayed wallet info
    @State private var walletAddress: String = "[hidden]"
    @State private var publicKeyString: String = "[hidden]"
    
    // Whether keys have been generated
    @State private var keysGenerated: Bool = false
    
    @State private var showMiningScreen = false
    
    // Loading spinner state
    @State private var isLoading: Bool = false
    
    @State private var generateKeysPulse = false
    @State private var hasGenerateKeysBeenPressed = false
    
    @State private var nextMiningPulse = false
    @State private var hasNextMiningBeenPressed = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple]),
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Displayed wallet info
                Text("Wallet Address:")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack {
                    Text(walletAddress)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .truncationMode(.middle)
                    // Copy-able wallet address
                    Button(action: {
                        UIPasteboard.general.string = walletAddress
                    }) {
                        Image(systemName: "doc.on.doc")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                Text("Public Key:")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack {
                    Text(publicKeyString)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .truncationMode(.middle)
                    // Copy-able public key
                    Button(action: {
                        UIPasteboard.general.string = publicKeyString
                    }) {
                        Image(systemName: "doc.on.doc")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                // "Generate Keys" button
                Button(action: {
                    BiometricAuthenticator.authenticateUser(reason: "Authenticate to generate your wallet keys") {
                        actuallyGenerateKeys()
                    } onFailure: { error in
                        print("Biometric Authentication failed: \(error?.localizedDescription ?? "")")
                    }
                    
                    // Stop pulsing after pressing
                    generateKeysPulse = false
                    hasGenerateKeysBeenPressed = true
                }) {
                    Text("Generate Keys")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .scaleEffect(generateKeysPulse ? 1.1 : 1.0)
                .animation(
                    generateKeysPulse
                    ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                    : .default,
                    value: generateKeysPulse
                )
                .onAppear {
                    if !hasGenerateKeysBeenPressed {
                        generateKeysPulse = true
                    } else {
                        generateKeysPulse = false
                    }
                }
                
                // Show "Retrieve Keys" only if keys are generated
                if keysGenerated {
                    Button(action: {
                        BiometricAuthenticator.authenticateUser(reason: "Authenticate to retrieve your wallet keys") {
                            actuallyRetrieveKeys()
                        } onFailure: { error in
                            print("Biometric Authentication failed: \(error?.localizedDescription ?? "")")
                        }
                    }) {
                        Text("Retrieve Keys")
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                
                // Show "Next → Mining" only if keys are generated
                if keysGenerated {
                    Button(action: {
                        nextMiningPulse = false
                        hasNextMiningBeenPressed = true
                        
                        // Show loading spinner
                        isLoading = true
                        
                        // Simulate a short delay so user sees the spinner before ARMiningScreen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            showMiningScreen = true
                            isLoading = false
                        }
                    }) {
                        Text("Next → Mining")
                            .font(.headline)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .scaleEffect(nextMiningPulse ? 1.1 : 1.0)
                    .animation(
                        nextMiningPulse
                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                        : .default,
                        value: nextMiningPulse
                    )
                    .onAppear {
                        if !hasNextMiningBeenPressed {
                            nextMiningPulse = true
                        } else {
                            nextMiningPulse = false
                        }
                    }
                    
                    if isLoading {
                        ProgressView("Loading AR...")
                            .padding(.top, 4)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showMiningScreen) {
            ARMiningScreen()
        }
    }
    
    // MARK: - Key Generation
    func actuallyGenerateKeys() {
        // Delete any old key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: "com.aravhawk.cryptolab.privatekey"
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let privateKeyAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: "com.aravhawk.cryptolab.privatekey"
        ]
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: privateKeyAttrs
        ]
        
        var error: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            if let error = error {
                print("Error generating private key: \(error.takeRetainedValue())")
            }
            return
        }
        // Mark as generated
        keysGenerated = true
    }
    
    // MARK: - Key Retrieval
    func actuallyRetrieveKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: "com.aravhawk.cryptolab.privatekey",
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let itemRef = item else {
            print("Error retrieving the private key.")
            return
        }
        let privateKey = itemRef as! SecKey
        
        guard let publicKey = getPublicKey(from: privateKey) else {
            print("Error deriving public key.")
            return
        }
        
        guard let address = deriveAddress(from: publicKey) else {
            print("Error deriving address.")
            return
        }
        
        walletAddress = address
        publicKeyString = publicKey.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Helpers
    func getPublicKey(from privateKey: SecKey) -> Data? {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            if let error = error {
                print("Error getting public key: \(error.takeRetainedValue())")
            }
            return nil
        }
        return publicKeyData
    }
    
    func deriveAddress(from publicKey: Data) -> String? {
        let publicKeyWithoutPrefix = Data(publicKey.dropFirst())
        let hashedPublicKey = SHA256.hash(data: publicKeyWithoutPrefix)
        let addressData = hashedPublicKey.suffix(20)
        return "0x" + addressData.map { String(format: "%02x", $0) }.joined()
    }
}
