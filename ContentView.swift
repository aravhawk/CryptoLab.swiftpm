//
//  ContentView.swift
//  CryptoLab
//
//  Created by Arav Jain on 1/9/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showLearnMorePopup = false

    // Pulsing controls
    @State private var learnMorePulse = false
    @State private var getStartedPulse = false

    // Tracks if Learn More was tapped
    @State private var hasLearnMoreBeenPressed = false

    // Existing states
    @State private var showLearnView = false

    // States of Get Started options page and CryptoCreationView
    @State private var showGetStartedView = false
    @State private var showCryptoCreationView = false

    var body: some View {
        ZStack {
            // Show 3 buttons if the user taps Get Started
            if showGetStartedView {
                GetStartedOptionsView(
                    onLearnAndBuild: {
                        withAnimation {
                            showGetStartedView = false
                            showLearnView = true
                        }
                    },
                    onSkipToBuilding: {
                        withAnimation {
                            showGetStartedView = false
                            showCryptoCreationView = true
                        }
                    }
                )
                .transition(.opacity)

            // If LearnView triggered
            } else if showLearnView {
                LearnView()
                    .transition(.opacity)

            // If CryptoCreationView triggered
            } else if showCryptoCreationView {
                CryptoCreationView()
                    .transition(.opacity)

            // Otherwise, show original welcome content
            } else {
                ZStack {
                    // Background
                    LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple, Color.green]),
                                   startPoint: .bottomLeading,
                                   endPoint: .topTrailing)
                    .edgesIgnoringSafeArea(.all)

                    // Main Content
                    VStack(spacing: 20) {
                        Image("CryptoLab App Icon Background Removed")
                            .resizable()
                            .frame(width: 150, height: 150)
                            .foregroundColor(.white)
                            .shadow(radius: 10)

                        Text("CryptoLab")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 5)

                        Text("Explore the world of cryptocurrencies, build your own tokens, and spark innovation!")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 40)

                        VStack(spacing: 15) {
                            FeatureCard(icon: "graduationcap.fill",
                                        title: "Learn About Crypto",
                                        description: "Quick, interactive lessons to grasp blockchain basics, consensus mechanisms, and more.")
                            FeatureCard(icon: "hexagon",
                                        title: "Create a Coin or Token",
                                        description: "Use the simulator to design and customize your cryptocurrency to the fullest.")
                            FeatureCard(icon: "arkit",
                                        title: "Experience Your Creation",
                                        description: "Simulate cryptography, wallets, and concensus mechanisms in an interactive AR experience.")
                        }
                        .padding(.horizontal, 20)
                        
                        Text("Pro tip: keep your device in landscape mode for the best experience!")

                        Spacer()

                        HStack(spacing: 15) {
                            Button(action: {
                                // Show the 3-button view
                                withAnimation {
                                    showGetStartedView = true
                                }
                            }) {
                                Text("Get Started")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                            .scaleEffect(getStartedPulse ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                                       value: getStartedPulse)

                            Button(action: {
                                showLearnMorePopup = true

                                // Stop Learn More pulsing, start Get Started pulsing
                                learnMorePulse = false
                                getStartedPulse = true
                                hasLearnMoreBeenPressed = true
                            }) {
                                Text("Learn More")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                            .scaleEffect(learnMorePulse ? 1.1 : 1.0)
                            .animation(
                                learnMorePulse
                                    ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                                    : .default,
                                value: learnMorePulse
                            )
                            .onAppear {
                                // Pulses only if not pressed before
                                if !hasLearnMoreBeenPressed {
                                    learnMorePulse = true
                                } else {
                                    learnMorePulse = false
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 40)

                    if showLearnMorePopup {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.scaleAnimation) {
                                    showLearnMorePopup = false
                                }
                            }
                            .zIndex(1)

                        LearnMoreView(onClose: {
                            withAnimation(.scaleAnimation) {
                                showLearnMorePopup = false
                            }
                        })
                        .transition(.scaleFromBottomTrailing)
                        .zIndex(2)
                    }
                }
                .animation(.scaleAnimation, value: showLearnMorePopup)
            }
        }
        // Apply fade animations
        .animation(.easeInOut(duration: 0.5), value: showLearnView)
        .animation(.easeInOut(duration: 0.5), value: showGetStartedView)
        .animation(.easeInOut(duration: 0.5), value: showCryptoCreationView)
    }
}

// MARK: - GetStartedOptionsView

struct GetStartedOptionsView: View {
    // Pulse "Learn & Build (recommended)"
    @State private var learnAndBuildPulse = false

    let onLearnAndBuild: () -> Void
    let onSkipToBuilding: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("Select an Option")
                .font(.largeTitle)

            Button("Learn & Build (recommended)") {
                onLearnAndBuild()
            }
            .font(.headline)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(learnAndBuildPulse ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 1)
                    .repeatForever(autoreverses: true),
                value: learnAndBuildPulse
            )
            .onAppear {
                learnAndBuildPulse = true
            }

            Button("Skip to Building") {
                onSkipToBuilding()
            }
            .font(.headline)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            // Teaser of soon-to-be-implemented features!
            Text("Coming soon! 👇")

            Button("Import Existing Crypto") {
                print("Imports are coming soon!")
            }
            .font(.headline)
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }
}

// MARK: - Custom Scale Transition

extension AnyTransition {
    static var scaleFromBottomTrailing: AnyTransition {
        .modifier(
            active: ScaleEffectModifier(isVisible: false),
            identity: ScaleEffectModifier(isVisible: true)
        )
    }
}

extension Animation {
    static var scaleAnimation: Animation {
        .easeInOut(duration: 0.7)
    }
}

// ViewModifier that scales and fades a view from/to bottom-trailing corner
struct ScaleEffectModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : 0.01, anchor: .bottomTrailing)
            .opacity(isVisible ? 1.0 : 0.0)
    }
}

// MARK: - LearnMoreView

struct LearnMoreView: View {
    let onClose: () -> Void
    @State private var daysUntilWWDC = 0

    @State private var closeButtonPulse = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Learn more about the app and WWDC!")
                .font(.system(size: 40))
                .fontWeight(.bold)
            FeatureCard(icon: "calendar",
                        title: "\(daysUntilWWDC) days until (expected) WWDC",
                        description: "Let's get excited for the big week!")
                .foregroundColor(.white)
                .onAppear {
                    calculateDaysUntilWWDC()
                }

            FeatureCard(icon: "paintpalette",
                        title: "App Theme/Styling",
                        description: "Gradients of blue and purple with a green accent")

            FeatureCard(icon: "gear",
                        title: "Version 0.1",
                        description: "The testing version before TestFlight and the App Store")

            FeatureCard(icon: "hammer",
                        title: "Developed by Arav Jain",
                        description: "A 14-year-old student who loves coding and all things Apple ")

            Spacer()

            Button(action: {
                onClose()
            }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(15)
                    .shadow(radius: 5)
            }
            .scaleEffect(closeButtonPulse ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 1)
                    .repeatForever(autoreverses: true),
                value: closeButtonPulse
            )
            .onAppear {
                closeButtonPulse = true
            }
            .padding()
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .bottomLeading,
                           endPoint: .topTrailing)
                .edgesIgnoringSafeArea(.all)
        )
    }

    private func calculateDaysUntilWWDC() {
        let targetDate = "2025-06-29"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let target = formatter.date(from: targetDate) else { return }

        let currentDate = Date()
        let components = Calendar.current.dateComponents([.day], from: currentDate, to: target)
        daysUntilWWDC = components.day ?? 0
    }
}

// MARK: - FeatureCard

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.green)
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}
