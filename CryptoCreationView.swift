//
//  CryptoCreationView.swift
//  CryptoLab
//
//  Created by Arav Jain on 1/23/25.
//

import SwiftUI
import PhotosUI

// MARK: - TypewriterText
struct TypewriterText: View {
    let text: String
    @State private var displayedText = ""
    @State private var timer: Timer?

    var body: some View {
        Text(displayedText)
            .onAppear {
                var index = 0
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    if index < text.count {
                        let nextIndex = text.index(text.startIndex, offsetBy: index)
                        displayedText.append(text[nextIndex])
                        index += 1
                    } else {
                        timer?.invalidate()
                        timer = nil
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

// MARK: - InfoButton
struct InfoButton: View {
    let description: String
    let width: CGFloat
    @State private var showPopover = false

    var body: some View {
        Button(action: {
            showPopover.toggle()
        }) {
            Image(systemName: "info.circle")
                .foregroundColor(.green)
        }
        .popover(isPresented: $showPopover, arrowEdge: .leading) {
            ScrollView {
                Text(description)
                    .padding()
                    // Fixed width, automatically adjusts height
                    .frame(width: width)
                    .multilineTextAlignment(.leading)
                    // Allows text to expand vertically
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// MARK: - CryptoCreationView
struct CryptoCreationView: View {
    // Use the shared environment object
    @EnvironmentObject var cryptoModel: CryptoModel

    // Local states for image selection and screen transitions
    @State private var image: Image? = nil
    @State private var showImagePicker = false
    @State private var inputImage: UIImage? = nil
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showActionSheet = false

    @State private var showNextScreen = false
    @State private var showDetails = false // Final screen

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .bottomLeading,
                           endPoint: .topTrailing)
                .edgesIgnoringSafeArea(.all)

            if showDetails {
                // Final details screen
                CryptoDetailsView(
                    creationType: cryptoModel.creationType,
                    cryptoName: cryptoModel.cryptoName,
                    ticker: cryptoModel.ticker,
                    blockchainName: cryptoModel.blockchainName,
                    consensusMechanism: cryptoModel.consensusMechanism,
                    algorithm: cryptoModel.algorithm,
                    selectedBlockchain: cryptoModel.selectedBlockchain,
                    image: image
                )
                .transition(.move(edge: .trailing))

            } else if showNextScreen {
                // Image selection screen
                PictureSelectionView(
                    image: $image,
                    inputImage: $inputImage,
                    sourceType: $sourceType,
                    showImagePicker: $showImagePicker,
                    showActionSheet: $showActionSheet,
                    showDetails: $showDetails
                )
                .transition(.opacity)

            } else {
                // Main form
                VStack(spacing: 20) {
                    TypewriterText(text: "Create Your Cryptocurrency")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    creationForm

                    Spacer()

                    // Next button if valid form
                    if isFormValid {
                        Button(action: {
                            withAnimation(.easeInOut) {
                                showNextScreen = true
                            }
                        }) {
                            Text("Next")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(15)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding()
            }
        }
        .animation(.easeInOut, value: showNextScreen)
    }

    // MARK: - Check if user filled out required fields
    private var isFormValid: Bool {
        if cryptoModel.creationType == "Coin" {
            return !cryptoModel.cryptoName.isEmpty
            && !cryptoModel.ticker.isEmpty
            && !cryptoModel.blockchainName.isEmpty
            && (
                (cryptoModel.consensusMechanism == "Proof-of-Work" && !cryptoModel.algorithm.isEmpty)
                || (cryptoModel.consensusMechanism != "Proof-of-Work" && !cryptoModel.consensusMechanism.isEmpty)
            )
        } else if cryptoModel.creationType == "Token" {
            return !cryptoModel.cryptoName.isEmpty
            && !cryptoModel.ticker.isEmpty
            && !cryptoModel.selectedBlockchain.isEmpty
        }
        return false
    }

    // MARK: - The coin/token form
    private var creationForm: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Create Coin or Token
            HStack {
                TypewriterText(text: "What do you want to create?")
                    .font(.headline)
                    .foregroundColor(.white)
                InfoButton(
                    description: """
                    Choose whether you want to create a new cryptocurrency (Coin)
                    with its own blockchain or a Token on an existing blockchain.
                    """,
                    width: 300
                )
            }
            Picker("Creation Type", selection: $cryptoModel.creationType) {
                Text("Coin").tag(Optional<String>("Coin"))
                Text("Token").tag(Optional<String>("Token"))
            }
            .pickerStyle(SegmentedPickerStyle())

            // User chose Coin
            if cryptoModel.creationType == "Coin" {
                coinFields
            }
            // User chose Token
            else if cryptoModel.creationType == "Token" {
                tokenFields
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Fields for "Coin"
    private var coinFields: some View {
        Group {
            // Crypto Name
            labeledTextField(
                labelText: "Cryptocurrency Name",
                placeholder: "Worldwide Developers Coin",
                boundText: $cryptoModel.cryptoName,
                info: "Enter the name of your new cryptocurrency."
            )

            // Ticker (req'd uppercase)
            if !cryptoModel.cryptoName.isEmpty {
                labeledTextField(
                    labelText: "Ticker Symbol",
                    placeholder: "WWDC",
                    boundText: Binding(
                        get: { cryptoModel.ticker },
                        set: { cryptoModel.ticker = $0.uppercased() }
                    ),
                    info: "Cryptocurrencies, like stocks, are traded under a short ticker symbol. This must be uppercase (e.g. BTC, ETH).",
                    isTicker: true
                )
            }

            // Blockchain Name
            if !cryptoModel.cryptoName.isEmpty && !cryptoModel.ticker.isEmpty {
                labeledTextField(
                    labelText: "Blockchain Name",
                    placeholder: "Swiftblock",
                    boundText: $cryptoModel.blockchainName,
                    info: "Enter the name of your blockchain."
                )
            }

            // Consensus mechanism
            if !cryptoModel.cryptoName.isEmpty
                && !cryptoModel.ticker.isEmpty
                && !cryptoModel.blockchainName.isEmpty {
                HStack {
                    TypewriterText(text: "Consensus Mechanism")
                        .font(.headline)
                        .foregroundColor(.white)
                    InfoButton(
                        description: "How are transactions validated? e.g., PoW, PoS, PoH.",
                        width: 300
                    )
                }
                Picker("Consensus Mechanism", selection: $cryptoModel.consensusMechanism) {
                    Text("Proof-of-Work").tag("Proof-of-Work")
                    Text("Proof-of-Stake").tag("Proof-of-Stake")
                    Text("Proof-of-History").tag("Proof-of-History")
                }
                .pickerStyle(SegmentedPickerStyle())

                // Mining Algorithm if PoW
                if cryptoModel.consensusMechanism == "Proof-of-Work" {
                    HStack {
                        TypewriterText(text: "Mining Algorithm")
                            .font(.headline)
                            .foregroundColor(.white)
                        InfoButton(
                            description: "Select the PoW algorithm (SHA-256, etc.).",
                            width: 300
                        )
                    }
                    Picker("Mining Algorithm", selection: $cryptoModel.algorithm) {
                        Text("SHA-256").tag("SHA-256")
                        Text("RandomX").tag("RandomX")
                        Text("KawPoW").tag("KawPoW")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
    }

    // MARK: - Fields for "Token"
    private var tokenFields: some View {
        Group {
            labeledTextField(
                labelText: "Token Name",
                placeholder: "Worldwide Developers Token",
                boundText: $cryptoModel.cryptoName,
                info: "Enter the name of your token."
            )

            if !cryptoModel.cryptoName.isEmpty {
                labeledTextField(
                    labelText: "Ticker Symbol",
                    placeholder: "WWDT",
                    boundText: Binding(
                        get: { cryptoModel.ticker },
                        set: { cryptoModel.ticker = $0.uppercased() }
                    ),
                    info: "Cryptocurrencies, like stocks, are traded under a short ticker symbol. This must be uppercase (e.g. BTC, ETH).",
                    isTicker: true
                )
            }

            if !cryptoModel.cryptoName.isEmpty && !cryptoModel.ticker.isEmpty {
                HStack {
                    TypewriterText(text: "Blockchain")
                        .font(.headline)
                        .foregroundColor(.white)
                    InfoButton(
                        description: "Choose the existing blockchain your token uses.",
                        width: 300
                    )
                }
                Picker("Blockchain", selection: $cryptoModel.selectedBlockchain) {
                    Text("Ethereum").tag("Ethereum")
                    Text("Solana").tag("Solana")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }

    // MARK: - Labeled text field helper
    private func labeledTextField(labelText: String,
                                  placeholder: String,
                                  boundText: Binding<String>,
                                  info: String,
                                  isTicker: Bool = false) -> some View
    {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                TypewriterText(text: labelText)
                    .font(.headline)
                    .foregroundColor(.white)
                InfoButton(description: info, width: 300)
            }
            TextField(placeholder, text: boundText)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)))
                .foregroundColor(.white)
                .autocapitalization(isTicker ? .allCharacters : .none)
        }
    }
}

// MARK: - PictureSelectionView
struct PictureSelectionView: View {
    @EnvironmentObject var cryptoModel: CryptoModel

    @Binding var image: Image?
    @Binding var inputImage: UIImage?
    @Binding var sourceType: UIImagePickerController.SourceType
    @Binding var showImagePicker: Bool
    @Binding var showActionSheet: Bool

    // After user finalizes, transition to details
    @Binding var showDetails: Bool

    @State private var selectImagePulse = false
    @State private var hasSelectImageBeenPressed = false

    @State private var finalizePulse = false
    @State private var hasFinalizeButtonPressed = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Set an icon")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text("You'll see a preview once you select an image")

            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 400, height: 400)
                    .clipShape(Circle())
            }

            Button("Select Image") {
                showActionSheet = true
                // Stop pulsing on click
                selectImagePulse = false
                hasSelectImageBeenPressed = true
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(title: Text("Select Image Source"), buttons: [
                    .default(Text("Photo Library")) {
                        sourceType = .photoLibrary
                        showImagePicker = true
                    },
                    .default(Text("Camera")) {
                        sourceType = .camera
                        showImagePicker = true
                    },
                    .cancel()
                ])
            }
            // Pulsing Select Image button
            .scaleEffect(selectImagePulse ? 1.1 : 1.0)
            .animation(
                selectImagePulse
                    ? Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
                    : .default,
                value: selectImagePulse
            )
            .onAppear {
                if !hasSelectImageBeenPressed {
                    selectImagePulse = true
                }
            }

            // Show Finalize Creation button only if user uploaded image
            if image != nil {
                Button("Finalize Creation") {
                    withAnimation(.easeInOut) {
                        showDetails = true
                    }
                    // Stop pulsing when button clicked
                    finalizePulse = false
                    hasFinalizeButtonPressed = true
                }
                .padding()
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                // Pulsing Finalize Creation button
                .scaleEffect(finalizePulse ? 1.1 : 1.0)
                .animation(
                    finalizePulse
                        ? Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
                        : .default,
                    value: finalizePulse
                )
                .onAppear {
                    // Start pulsing if never pressed
                    if !hasFinalizeButtonPressed {
                        finalizePulse = true
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showImagePicker, onDismiss: loadImage) {
            ImagePicker(image: $inputImage, sourceType: sourceType)
        }
    }

    func loadImage() {
        // If user picked an image, display it AND convert to base64
        if let uiImage = inputImage {
            image = Image(uiImage: uiImage)

            // Convert the selected image to base64 and store in CryptoModel
            if let jpegData = uiImage.jpegData(compressionQuality: 1.0) {
                cryptoModel.coinImageBase64 = jpegData.base64EncodedString()
            }
        }
    }
}

// MARK: - CryptoDetailsView
// Final screen, displays all crypto details + image
struct CryptoDetailsView: View {
    let creationType: String?
    let cryptoName: String
    let ticker: String
    let blockchainName: String
    let consensusMechanism: String
    let algorithm: String
    let selectedBlockchain: String
    let image: Image?

    @State private var showWalletView = false

    @State private var animatePulse = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .bottomLeading,
                           endPoint: .topTrailing)
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 20) {
                    Text("Your Crypto is Ready!")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding(.top, 40)
                        .multilineTextAlignment(.center)

                    // Pulsing Continue to Wallet button
                    Button(action: {
                        showWalletView = true
                    }) {
                        Text("Continue to Wallet →")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                            .padding(.top, 10)
                            .scaleEffect(animatePulse ? 1.1 : 1.0)
                    }
                    .onAppear {
                        withAnimation(
                            Animation.easeInOut(duration: 1)
                                .repeatForever(autoreverses: true)
                        ) {
                            animatePulse = true
                        }
                    }
                    .fullScreenCover(isPresented: $showWalletView) {
                        WalletGenerationView()
                    }

                    // Chosen image displayed inside a circle
                    if let image = image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                    }

                    // Display all fields
                    Group {
                        detailRow("Type:", creationType ?? "")
                        detailRow("Name:", cryptoName)
                        detailRow("Ticker:", ticker)

                        if creationType == "Coin" {
                            detailRow("Blockchain:", blockchainName)
                            detailRow("Consensus:", consensusMechanism)
                            if consensusMechanism == "Proof-of-Work" {
                                detailRow("Algorithm:", algorithm)
                            }
                        } else if creationType == "Token" {
                            detailRow("Chain:", selectedBlockchain)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 40)
                }
                .padding(.bottom, 50)
            }
        }
    }

    // Helper for detail rows
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }
}
