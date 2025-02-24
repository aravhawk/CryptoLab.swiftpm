//
//  CryptoModel.swift
//  CryptoLab
//
//  Created by Arav Jain on 2/17/25.
//

import SwiftUI

class CryptoModel: ObservableObject, Codable {
    @Published var creationType: String? = nil {
        didSet {
            // Reset consensusMechanism when creationType changes
            if creationType == "Token" {
                updateConsensusMechanismForToken()
            } else if creationType == "Coin" {
                // Reset consensusMechanism for Coin to allow manual selection
                consensusMechanism = ""
            }
        }
    }
    @Published var cryptoName: String = ""
    @Published var ticker: String = ""
    @Published var blockchainName: String = ""
    @Published var consensusMechanism: String = ""
    @Published var algorithm: String = ""
    @Published var selectedBlockchain: String = "" {
        didSet {
            if creationType == "Token" {
                updateConsensusMechanismForToken()
            }
        }
    }
    @Published var coinImageBase64: String? = nil

    // Enum to match the keys
    enum CodingKeys: String, CodingKey {
        case creationType
        case cryptoName
        case ticker
        case blockchainName
        case consensusMechanism
        case algorithm
        case selectedBlockchain
        case coinImageBase64
    }

    // Encode properties
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(creationType, forKey: .creationType)
        try container.encode(cryptoName, forKey: .cryptoName)
        try container.encode(ticker, forKey: .ticker)
        try container.encode(blockchainName, forKey: .blockchainName)
        try container.encode(consensusMechanism, forKey: .consensusMechanism)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(selectedBlockchain, forKey: .selectedBlockchain)
        try container.encode(coinImageBase64, forKey: .coinImageBase64)
    }

    // Decode properties
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creationType = try container.decodeIfPresent(String.self, forKey: .creationType)
        cryptoName = try container.decode(String.self, forKey: .cryptoName)
        ticker = try container.decode(String.self, forKey: .ticker)
        blockchainName = try container.decode(String.self, forKey: .blockchainName)
        consensusMechanism = try container.decode(String.self, forKey: .consensusMechanism)
        algorithm = try container.decode(String.self, forKey: .algorithm)
        selectedBlockchain = try container.decode(String.self, forKey: .selectedBlockchain)
        coinImageBase64 = try container.decodeIfPresent(String.self, forKey: .coinImageBase64)
    }

    init() {}

    // New helper function to update consensusMechanism for Tokens
    private func updateConsensusMechanismForToken() {
        switch selectedBlockchain {
        case "Ethereum":
            consensusMechanism = "Proof-of-Stake"
        case "Solana":
            consensusMechanism = "Proof-of-History"
        default:
            consensusMechanism = ""
        }
    }
}
