//
//  LearnView.swift
//  CryptoLab
//
//  Created by Arav Jain on 1/19/25.
//

import SwiftUI

struct LearnView: View {
    @State private var currentPage = 0
    @State private var displayedText = "" // Holds currently visible text
    @State private var timer: Timer? = nil // Controls typewriter effect
    @State private var rightArrowPulse = false // Pulse state of right arrow in main pages

    @State private var showFinalScreen = false
    @State private var showMakeCryptoAnnounceView = true
    @State private var rightArrowPulseFinal = false // Pulse state for arrow on final screen
    @State private var showFinalText = false // Triggers text animation in MakeCryptoAnnounceView

    @Namespace private var animationNamespace

    // Content for each page
    let pages = [
        (
            "Crypto 101: The Big Picture",
            """
            Cryptocurrencies are digital assets run by a global network, not a central bank. Transactions are recorded on a blockchain—a secure, transparent ledger that’s nearly impossible to alter.

            This tech slices out middlemen like banks, giving people worldwide the freedom to send money fast and at lower fees.

            • Bitcoin led the way by showing how cryptography can replace traditional trust systems.
            • Blockchain data is public, so anyone can see transactions in real time.
            • Once a block is confirmed, it’s locked in permanently (immutable).
            """,
            "cryptoBasics"
        ),
        (
            "Securing the Network: Cryptography & Keys",
            """
            Crypto transactions use a pair of keys—a public key (your shareable address) and a private key (your secret signature tool). Only the true owner, armed with the private key, can sign transactions, which keeps your funds secure from sneaky attackers.

            • Wallet addresses are usually created by hashing your public key.
            • Transactions get a tamper-proof signature when signed with your private key.
            • Blockchains use robust hashing algorithms (like SHA‑256, RandomX, and KawPoW) to lock down data.
            """,
            "cryptoKeys"
        ),
        (
            "Consensus Mechanisms & Rewards",
            """
            A blockchain’s consensus mechanism makes sure everyone agrees on which transactions are valid. Different methods secure the network while rewarding honest participants:

            • Proof-of-Work (PoW): Miners solve tough puzzles to earn coins and fees—super secure but energy-hungry (think Bitcoin).
            • Proof-of-Stake (PoS): Validators lock up their coins and get randomly picked to confirm blocks, earning tokens or fees (like Ethereum 2.0 with a lighter energy load).
            • Proof-of-History (PoH): Uses cryptographic timestamps to create a verifiable timeline (as seen with Solana), rewarding those who help secure the network.

            Each method strikes its own balance between security, speed, and energy efficiency, ensuring that honest behavior is always in the winner’s circle.
            """,
            "consensusMechanisms"
        ),
        (
            "Practical Uses & Next Steps",
            """
            Cryptocurrencies now power smart contracts, DeFi, and NFTs—unlocking new realms in digital art, gaming, and community building. Layer‑2 solutions, sidechains, and eco-friendly initiatives are making these systems faster, cheaper, and greener. Always stay updated and keep your private keys secure!

            • DeFi enables bank-free lending, borrowing, and trading.
            • NFTs verify unique digital ownership.
            • Hybrid blockchains and sidechains cut fees and boost speed.
            • Cross‑chain compatibility is on the horizon for seamless blockchain interactions.
            """,
            "futureOutlook"
        )
    ]

    var body: some View {
        ZStack {
            // If reached final screen:
            if showFinalScreen {
                // Then show either MakeCryptoAnnounceView or CryptoCreationView
                if showMakeCryptoAnnounceView {
                    MakeCryptoAnnounceView(showFinalText: $showFinalText,
                                           rightArrowPulseFinal: $rightArrowPulseFinal,
                                           onNext: {
                        // When arrow tapped, switch to CryptoCreationView w/ fade
                        withAnimation(.easeInOut(duration: 0.8)) {
                            showMakeCryptoAnnounceView = false
                        }
                    })
                    .transition(.opacity)
                } else {
                    CryptoCreationView()
                        .transition(.opacity)
                }
            }
            else {
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                               startPoint: .bottomLeading,
                               endPoint: .topTrailing)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    // Title
                    Text(pages[currentPage].0)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // Image with Animation
                    ZStack {
                        ForEach(0..<pages.count, id: \.self) { index in
                            if index == currentPage {
                                Image(pages[index].2)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(radius: 5)
                                    .padding()
                                    .matchedGeometryEffect(id: "pageImage", in: animationNamespace)
                            }
                        }
                    }

                    // Scrollable text with auto-scroll (helpful for easily adding more content)
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(displayedText)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .id("typewriterText") // Unique ID for scrolling
                        }
                        .onChange(of: displayedText) {
                            DispatchQueue.main.async {
                                proxy.scrollTo("typewriterText", anchor: .bottom)
                            }
                        }
                    }

                    // Navigation Buttons
                    HStack {
                        Button(action: {
                            if currentPage > 0 {
                                changePage(to: currentPage - 1)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                        .disabled(currentPage == 0)

                        Spacer()

                        Button(action: {
                            if currentPage < pages.count - 1 {
                                changePage(to: currentPage + 1)
                            } else {
                                // Once user finishes final page, show MakeCryptoAnnounceView
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    showFinalScreen = true
                                    showFinalText = true
                                }
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.2)))
                                .scaleEffect(rightArrowPulse ? 1.2 : 1.0)
                                .animation(
                                    .easeInOut(duration: 1)
                                        .repeatForever(autoreverses: true),
                                    value: rightArrowPulse
                                )
                        }
                        .onAppear {
                            rightArrowPulse = true
                        }
                    }
                    .padding(.horizontal, 40)
                    .foregroundColor(.white)
                }
                .padding()
            }
        }
        .onAppear {
            startTypewriterEffect()
        }
    }

    // Typewriter effect for page text
    private func startTypewriterEffect() {
        displayedText = ""
        let fullText = pages[currentPage].1

        timer?.invalidate()

        var currentIndex = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            if currentIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
                displayedText.append(fullText[index])
                currentIndex += 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func changePage(to newPage: Int) {
        withAnimation(.easeInOut) {
            currentPage = newPage
        }
        startTypewriterEffect()
    }
}

// MARK: - MakeCryptoAnnounceView
struct MakeCryptoAnnounceView: View {
    @Binding var showFinalText: Bool
    @Binding var rightArrowPulseFinal: Bool

    let onNext: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .bottomLeading,
                           endPoint: .topTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                Spacer()

                if showFinalText {
                    Text("Now that we've got the basics down...\nLet's make our own cryptocurrency!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .transition(.move(edge: .trailing))
                }

                Spacer()

                // Arrow button at bottom
                HStack {
                    Spacer()

                    Button(action: {
                        onNext()
                    }) {
                        HStack {
                            Text("Let's do this!")
                            Image(systemName: "chevron.right")
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                        .scaleEffect(rightArrowPulseFinal ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1)
                            .repeatForever(autoreverses: true),
                            value: rightArrowPulseFinal
                        )
                    }
                    .onAppear {
                        // Start pulse final arrow
                        rightArrowPulseFinal = true
                    }
                }
                .padding(.horizontal, 40)
                .foregroundColor(.white)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                showFinalText = true
            }
        }
    }
}
