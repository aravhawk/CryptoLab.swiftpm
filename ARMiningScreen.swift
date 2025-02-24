//
//  ARMiningScreen.swift
//  CryptoLab
//
//  Created by Arav Jain on 2/14/25.
//

import SwiftUI
import ARKit
import RealityKit
import CryptoKit
import Security
import UIKit

// MARK: - Main Screen
struct ARMiningScreen: View {
    @EnvironmentObject var cryptoModel: CryptoModel
    @StateObject private var coordinator = ARMiningCoordinator()
    
    // Transact popup states
    @State private var showSendPopup = false
    @State private var showReceivePopup = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    // AR View
                    ZStack {
                        ARRepresentableView(coordinator: coordinator)
                            .frame(width: geo.size.width * 0.75)
                            .ignoresSafeArea()
                    }
                    
                    Divider()
                    
                    // Sidebar
                    SidebarView(
                        showSendPopup: $showSendPopup,
                        showReceivePopup: $showReceivePopup
                    )
                    .environmentObject(coordinator)
                    .environmentObject(cryptoModel)
                    .frame(width: geo.size.width * 0.25)
                    .ignoresSafeArea()
                }
                
                // Popups
                if showSendPopup {
                    ZStack {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation {
                                    showSendPopup = false
                                }
                            }
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                ZStack(alignment: .topTrailing) {
                                    Color.black.opacity(0.8)
                                        .cornerRadius(12)
                                    
                                    TransactionCreationView()
                                        .environmentObject(coordinator)
                                        .padding()
                                    
                                    Button {
                                        withAnimation {
                                            showSendPopup = false
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding(8)
                                    }
                                }
                                .frame(width: 350)
                                .fixedSize(horizontal: false, vertical: true)
                                .shadow(radius: 8)
                                Spacer()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .transition(.scale)
                }
                
                if showReceivePopup {
                    ZStack {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation {
                                    showReceivePopup = false
                                }
                            }
                        ReceivePopupView(showReceivePopup: $showReceivePopup)
                    }
                    .transition(.scale)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Set consensus mechanism and complementing balance
            switch cryptoModel.consensusMechanism {
            case "Proof-of-Work":
                coordinator.consensusAlgorithm = .pow
                coordinator.balance = 0.0
            case "Proof-of-Stake":
                coordinator.consensusAlgorithm = .pos
                coordinator.balance = 1.0
            case "Proof-of-History":
                coordinator.consensusAlgorithm = .poh
                coordinator.balance = 0.0
            default:
                coordinator.consensusAlgorithm = .pow
                coordinator.balance = 0.0
            }
        }
    }
}

// MARK: - ARRepresentableView
struct ARRepresentableView: UIViewRepresentable {
    @ObservedObject var coordinator: ARMiningCoordinator
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure session
        arView.automaticallyConfigureSession = false
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [])
        
        coordinator.arView = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - ARMiningCoordinator
class ARMiningCoordinator: NSObject, ObservableObject {
    weak var arView: ARView?
    
    private var walletAnchor: AnchorEntity?
    private var coinEntities: [ModelEntity] = []
    
    private let walletHeight: Float = 0.02
    private let coinHeight:   Float = 0.02
    private let spacing:      Float = 0.0
    
    @Published var balance: Double = 0.0 {
        didSet {
            DispatchQueue.main.async {
                self.updateCoinStack()
            }
        }
    }
    @Published var walletPlaced: Bool = false
    
    enum ConsensusAlgorithm { case pow, pos, poh }
    @Published var consensusAlgorithm: ConsensusAlgorithm = .pow
    
    // Mining states
    @Published var isMining: Bool = false
    @Published var miningProgress: Double = 0.0
    private var miningTimer: Timer?
    @Published var miningOutcome: Bool? = nil
    
    // For logging behind-the-scenes steps
    @Published var powAttempts: [PoWAttempt] = []
    @Published var posRounds: [PoSRound] = []
    @Published var pohEvents: [PoHEvent] = []
    
    // MARK: - Place Wallet
    // Best performance and experience when placed from bird's eye view
    func placeWallet() {
        guard let arView = arView else { return }
        let centerPoint = CGPoint(x: arView.frame.midX, y: arView.frame.midY)
        
        // Try recognized-plane geometry
        let results1 = arView.raycast(from: centerPoint, allowing: .existingPlaneGeometry, alignment: .horizontal)
        if let firstHit = results1.first {
            placeWalletEntity(hitResult: firstHit, in: arView)
            return
        }
        
        // If that fails, try .estimatedPlane
        let results2 = arView.raycast(from: centerPoint, allowing: .estimatedPlane, alignment: .horizontal)
        if let secondHit = results2.first {
            placeWalletEntity(hitResult: secondHit, in: arView)
            return
        }
        
        // If that also fails, fallback in front of the camera
        fallbackPlacement(arView: arView)
    }
    
    private func placeWalletEntity(hitResult: ARRaycastResult, in arView: ARView) {
        let position = hitResult.worldTransform.translation
        let anchor = AnchorEntity(world: position)
        
        let wallet = ModelEntity(mesh: .generateBox(size: [0.15, walletHeight, 0.1]))
        wallet.model?.materials = [
            SimpleMaterial(color: .brown, isMetallic: false)
        ]
        wallet.position.y = walletHeight / 2
        
        anchor.addChild(wallet)
        arView.scene.addAnchor(anchor)
        
        walletAnchor = anchor
        coinEntities = []
        
        DispatchQueue.main.async {
            self.walletPlaced = true
            self.updateCoinStack()
        }
    }
    
    private func fallbackPlacement(arView: ARView) {
        var transform = arView.cameraTransform
        // Move forward .5m
        transform.translation += transform.rotation.act(SIMD3<Float>(0, 0, -0.5))
        
        let anchor = AnchorEntity()
        anchor.transform = transform
        
        let wallet = ModelEntity(mesh: .generateBox(size: [0.15, walletHeight, 0.1]))
        wallet.model?.materials = [
            SimpleMaterial(color: .brown, isMetallic: false)
        ]
        wallet.position.y = walletHeight / 2
        
        anchor.addChild(wallet)
        arView.scene.addAnchor(anchor)
        
        walletAnchor = anchor
        coinEntities = []
        
        DispatchQueue.main.async {
            self.walletPlaced = true
            self.updateCoinStack()
        }
    }
    
    // MARK: - Mining
    func mine() {
        switch consensusAlgorithm {
        case .pow:
            minePow()
        case .pos:
            minePos()
        case .poh:
            minePoh()
        }
    }
    
    func stopMining() {
        miningTimer?.invalidate()
        miningTimer = nil
        isMining = false
    }
    
    // MARK: - Proof of Work (50/50 each attempt)
    private func minePow() {
        guard !isMining else { return }
        isMining = true
        miningProgress = 0.0
        miningOutcome = nil
        
        powAttempts.removeAll()
        
        let totalAttempts = 20
        var currentIteration = 0
        var acceptedCount = 0
        
        miningTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            currentIteration += 1
            let success = Bool.random()
            if success { acceptedCount += 1 }
            
            let attempt = PoWAttempt(iteration: currentIteration, accepted: success)
            DispatchQueue.main.async {
                self.powAttempts.append(attempt)
                self.miningProgress = Double(currentIteration) / Double(totalAttempts)
            }
            
            if currentIteration >= totalAttempts {
                self.stopMining()
                let finalOutcome = (acceptedCount > 0)
                self.miningOutcome = finalOutcome
                if finalOutcome {
                    DispatchQueue.main.async {
                        self.balance += 5.0
                    }
                }
            }
        }
    }
    
    // MARK: - Proof of Stake (50/50 each round)
    private func minePos() {
        guard !isMining else { return }
        isMining = true
        miningProgress = 0.0
        miningOutcome = nil
        
        posRounds.removeAll()
        
        let oldBalance = balance
        balance = 0.0 // lock stake
        
        let totalRounds = 20
        var currentRound = 0
        var acceptedCount = 0
        
        miningTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            currentRound += 1
            let success = Bool.random()
            if success { acceptedCount += 1 }
            
            let round = PoSRound(iteration: currentRound, accepted: success)
            DispatchQueue.main.async {
                self.posRounds.append(round)
                self.miningProgress = Double(currentRound) / Double(totalRounds)
            }
            
            if currentRound >= totalRounds {
                self.stopMining()
                let finalOutcome = (acceptedCount > 0)
                self.miningOutcome = finalOutcome
                if finalOutcome {
                    DispatchQueue.main.async {
                        self.balance = oldBalance * 2
                    }
                } else {
                    DispatchQueue.main.async {
                        self.balance = oldBalance
                    }
                }
            }
        }
    }
    
    // MARK: - Proof of History
    private func minePoh() {
        guard !isMining else { return }
        isMining = true
        miningProgress = 0.0
        miningOutcome = nil
        
        pohEvents.removeAll()
        
        let chainLength = 10
        var currentIndex = 0
        var lastHashData = Data("GENESIS-\(Date().timeIntervalSince1970)".utf8)
        
        miningTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let eventTime = Date().timeIntervalSince1970
            let combinedData = lastHashData + Data("\(eventTime)".utf8)
            let newHash = SHA256.hash(data: combinedData)
            let newHashData = Data(newHash)
            let newHashString = newHashData.map { String(format: "%02x", $0) }.joined()
            
            let event = PoHEvent(index: currentIndex, timestamp: eventTime, hashString: newHashString)
            DispatchQueue.main.async {
                self.pohEvents.append(event)
                self.miningProgress = Double(currentIndex + 1) / Double(chainLength)
            }
            
            lastHashData = newHashData
            currentIndex += 1
            
            if currentIndex >= chainLength {
                self.stopMining()
                DispatchQueue.main.async {
                    self.balance += 3.0
                }
                self.miningOutcome = true
            }
        }
    }
    
    // MARK: - Coin Stack
    private func updateCoinStack() {
        guard walletAnchor != nil else { return }
        let desiredCoinCount = Int(balance)
        let currentCoinCount = coinEntities.count
        
        if desiredCoinCount > currentCoinCount {
            let coinsToAdd = desiredCoinCount - currentCoinCount
            for _ in 0..<coinsToAdd {
                addCoinEntity()
            }
        } else if desiredCoinCount < currentCoinCount {
            let coinsToRemove = currentCoinCount - desiredCoinCount
            for _ in 0..<coinsToRemove {
                removeCoinEntity()
            }
        }
    }
    
    private func addCoinEntity() {
        guard let walletAnchor = walletAnchor else { return }
        let coinEntity = ModelEntity(mesh: .generateSphere(radius: 0.05))
        coinEntity.model?.materials = [UnlitMaterial(color: UIColor(hex: "#FFD700")!)]
        coinEntity.transform.scale = [1.0, 0.2, 1.0]
        
        let coinIndex = coinEntities.count
        let yOffset = walletHeight + (coinHeight / 2) +
        Float(coinIndex) * (coinHeight + spacing)
        coinEntity.position = [0, yOffset, 0]
        
        walletAnchor.addChild(coinEntity)
        coinEntities.append(coinEntity)
    }
    
    private func removeCoinEntity() {
        if let lastCoin = coinEntities.popLast() {
            lastCoin.removeFromParent()
        }
    }
}

// MARK: - SidebarView
struct SidebarView: View {
    @EnvironmentObject var coordinator: ARMiningCoordinator
    @EnvironmentObject var cryptoModel: CryptoModel
    
    @Binding var showSendPopup: Bool
    @Binding var showReceivePopup: Bool
    
    enum CurrentStep {
        case walletPlacement
        case miningInfo
        case transactionInfo
        case mainContent
    }
    @State private var currentStep: CurrentStep = .walletPlacement
    @State private var isAnimating = false
    
    // Sharing
    @State private var animateSharePulse = false
    @State private var hasShareButtonBeenPressed = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    
    var body: some View {
        VStack {
            switch currentStep {
            case .walletPlacement:
                VStack(spacing: 20) {
                    Text("Move your iPad around so its camera captures your surroundings, for a few seconds. Then, find a flat surface—like a table—and position your iPad 8-12 inches above it in a bird’s-eye view, ensuring it remains flat. Tap Place Wallet, and then tilt your device to a side or diagonal angle to see your wallet in action!")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        coordinator.placeWallet()
                    }) {
                        Text("Place Wallet")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                    .onAppear { isAnimating = true }
                }
                .frame(maxWidth: .infinity)
                .onChange(of: coordinator.walletPlaced) { _, newValue in
                    if newValue {
                        currentStep = .miningInfo
                    }
                }
                
            case .miningInfo:
                VStack(spacing: 20) {
                    Text(miningInfoText())
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        currentStep = .transactionInfo
                    }) {
                        Text("Next")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                    .onAppear { isAnimating = true }
                }
                .frame(maxWidth: .infinity)
                
            case .transactionInfo:
                VStack(spacing: 20) {
                    Text("You can receive coins from others using your QR code or send coins to other users.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        currentStep = .mainContent
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                    .onAppear { isAnimating = true }
                }
                .frame(maxWidth: .infinity)
                
            case .mainContent:
                Text("Wallet")
                    .font(.title)
                    .padding(.top, 30)
                Divider().padding(.vertical, 10)
                
                MiningBubbleView()
                    .environmentObject(coordinator)
                
                Divider().padding(.vertical, 10)
                
                // Transact bubble
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transact")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        showSendPopup = true
                    }) {
                        Text("Send")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showReceivePopup = true
                    }) {
                        Text("Receive")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                Spacer()
                
                // Balance bubble
                VStack(alignment: .leading, spacing: 8) {
                    Text("Balance: \(String(format: "%.2f", coordinator.balance)) \(cryptoModel.ticker)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                // Share Token/Coin
                Button(action: {
                    hasShareButtonBeenPressed = true
                    animateSharePulse = false
                    showShareSheet = true
                    prepareShareToken()
                }) {
                    let buttonText = cryptoModel.creationType == "Token" ? "Share Token" : "Share Coin"
                    Text(buttonText)
                        .font(.headline)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .scaleEffect(animateSharePulse ? 1.1 : 1.0)
                .animation(
                    animateSharePulse
                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    : .default,
                    value: animateSharePulse
                )
                .onAppear {
                    if !hasShareButtonBeenPressed {
                        animateSharePulse = true
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    if let shareURL = shareURL {
                        ActivityViewController(activityItems: [shareURL])
                    } else {
                        Text("Unable to share the token.")
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
    }
    
    // Dynamically choose text for the "miningInfo" step
    private func miningInfoText() -> String {
        let firstLine: String
        switch coordinator.consensusAlgorithm {
        case .pow:
            firstLine = "You can earn coins by mining."
        case .pos:
            firstLine = "You can earn coins by staking."
        case .poh:
            firstLine = "You can earn coins by building timelines."
        }
        
        let secondLine = "Your AR wallet will update to reflect your earnings."
        let thirdLine  = "You may see attempts get rejected but can try again."
        
        return "\(firstLine)\n\(secondLine)\n\(thirdLine)"
    }
    
    // Prepare file to share
    func prepareShareToken() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(cryptoModel)
            let tempDir = FileManager.default.temporaryDirectory
            
            var fileExtension: String
            if cryptoModel.creationType == "Coin" {
                fileExtension = "clcoin"
            } else if cryptoModel.creationType == "Token" {
                fileExtension = "cltoken"
            } else {
                fileExtension = "clcoin"
            }
            let fileName = "\(cryptoModel.cryptoName).\(fileExtension)"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            self.shareURL = fileURL
        } catch {
            print("⚠️ Error encoding or writing crypto data: \(error)")
            self.shareURL = nil
        }
    }
}

// MARK: - MiningBubbleView
struct MiningBubbleView: View {
    @EnvironmentObject var coordinator: ARMiningCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mining")
                .font(.headline)
                .foregroundColor(.white)
            
            switch coordinator.consensusAlgorithm {
            case .pow:
                powUI
            case .pos:
                posUI
            case .poh:
                pohUI
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    // Proof of Work UI
    private var powUI: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Proof of Work")
                .foregroundColor(.white)
                .font(.headline)
            
            ProgressView(value: coordinator.miningProgress, total: 1.0)
                .accentColor(.yellow)
            
            HStack {
                if coordinator.isMining {
                    Button("Stop") {
                        coordinator.stopMining()
                    }
                    .padding(6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                } else {
                    Button("Start Mining") {
                        coordinator.mine()
                    }
                    .padding(6)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
            }
            
            if let outcome = coordinator.miningOutcome {
                if outcome {
                    Text("Mining complete: share accepted! +5 reward.")
                        .foregroundColor(.green)
                } else {
                    Text("Mining complete: all attempts rejected, no reward.")
                        .foregroundColor(.red)
                }
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(coordinator.powAttempts) { attempt in
                            Text("Attempt #\(attempt.iteration): " +
                                 (attempt.accepted ? "Share accepted" : "Share rejected"))
                            .font(.caption)
                            .foregroundColor(attempt.accepted ? .green : .red)
                            .id(attempt.id) // Assign ID for scrolling
                        }
                    }
                }
                .onChange(of: coordinator.powAttempts.count) { oldValue, newValue in
                    if newValue > oldValue, let lastAttempt = coordinator.powAttempts.last {
                        withAnimation {
                            proxy.scrollTo(lastAttempt.id, anchor: .bottom)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }
    
    // Proof of Stake UI
    private var posUI: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Proof of Stake")
                .foregroundColor(.white)
                .font(.headline)
            
            ProgressView(value: coordinator.miningProgress, total: 1.0)
                .accentColor(.green)
            
            HStack {
                if coordinator.isMining {
                    Button("Stop") {
                        coordinator.stopMining()
                    }
                    .padding(6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                } else {
                    Button("Start Staking") {
                        coordinator.mine()
                    }
                    .padding(6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            
            if let outcome = coordinator.miningOutcome {
                if outcome {
                    Text("Staking complete: stake accepted! Balance doubled.")
                        .foregroundColor(.green)
                } else {
                    Text("Staking complete: all attempts rejected, no reward.")
                        .foregroundColor(.red)
                }
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(coordinator.posRounds) { round in
                            Text("Round #\(round.iteration): " +
                                 (round.accepted ? "Stake accepted" : "Stake rejected"))
                            .font(.caption)
                            .foregroundColor(round.accepted ? .green : .red)
                            .id(round.id) // Assign ID for scrolling
                        }
                    }
                }
                .onChange(of: coordinator.posRounds.count) { oldValue, newValue in
                    if newValue > oldValue, let lastRound = coordinator.posRounds.last {
                        withAnimation {
                            proxy.scrollTo(lastRound.id, anchor: .bottom)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }
    
    // Proof of History UI
    private var pohUI: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Proof of History")
                .foregroundColor(.white)
                .font(.headline)
            
            if coordinator.isMining {
                Text("Building historical record...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            } else if coordinator.pohEvents.isEmpty {
                Text("No PoH chain yet. Tap 'Start PoH' to generate one.")
                    .foregroundColor(.white)
                    .font(.subheadline)
            } else {
                Text("Completed Chain (\(coordinator.pohEvents.count) events):")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            
            ProgressView(value: coordinator.miningProgress, total: 1.0)
                .accentColor(.blue)
            
            HStack {
                if coordinator.isMining {
                    Button("Stop") {
                        coordinator.stopMining()
                    }
                    .padding(6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                } else {
                    Button("Start PoH") {
                        coordinator.mine()
                    }
                    .padding(6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            
            if let outcome = coordinator.miningOutcome, outcome {
                Text("PoH chain built. +3 reward!")
                    .foregroundColor(.green)
                    .padding(.top, 5)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(coordinator.pohEvents) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Step \(event.index) @ \(String(format: "%.2f", event.timestamp))")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(event.hashString)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.bottom, 6)
                            .id(event.id) // Assign ID for scrolling
                        }
                    }
                }
                .onChange(of: coordinator.pohEvents.count) { oldValue, newValue in
                    if newValue > oldValue, let lastEvent = coordinator.pohEvents.last {
                        withAnimation {
                            proxy.scrollTo(lastEvent.id, anchor: .bottom)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

// MARK: - PoWAttempt / PoSRound / PoHEvent
struct PoWAttempt: Identifiable {
    let id = UUID()
    let iteration: Int
    let accepted: Bool
}

struct PoSRound: Identifiable {
    let id = UUID()
    let iteration: Int
    let accepted: Bool
}

struct PoHEvent: Identifiable {
    let id = UUID()
    let index: Int
    let timestamp: TimeInterval
    let hashString: String
}

// MARK: - TransactionCreationView
struct TransactionCreationView: View {
    @EnvironmentObject var coordinator: ARMiningCoordinator
    
    @State private var receiverAddress: String = ""
    @State private var amount: String = ""
    @State private var pendingTransactionDetails: String = ""
    @State private var transactionDetails: String = ""
    @State private var transactionSignature: String = ""
    @State private var lastTransactionData: Data? = nil
    @State private var verificationMessage: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Create Transaction")
                .font(.headline)
            
            TextField("Receiver Address or Name", text: $receiverAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Amount", text: $amount)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
            
            Button(action: {
                BiometricAuthenticator.authenticateUser(
                    reason: "Authenticate to sign transaction"
                ) {
                    signTransaction()
                } onFailure: { error in
                    verificationMessage = "Biometric authentication failed. \(error?.localizedDescription ?? "")"
                }
            }) {
                Text("Sign Transaction")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if !transactionSignature.isEmpty {
                Text("Transaction Signature:")
                    .font(.subheadline)
                Text(transactionSignature)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .padding(.bottom, 5)
                
                Button(action: verifyTransaction) {
                    Text("Verify Transaction")
                        .font(.headline)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            if !verificationMessage.isEmpty {
                Text(verificationMessage)
                    .foregroundColor(verificationMessage.contains("Verified") ? .green : .red)
                    .padding(.top, 8)
                
                if verificationMessage.contains("Verified"), !transactionDetails.isEmpty {
                    Text("Transaction Details:")
                        .font(.subheadline)
                    Text(transactionDetails)
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .onDisappear {
            resetAllFields()
        }
    }
    
    func resetAllFields() {
        receiverAddress = ""
        amount = ""
        pendingTransactionDetails = ""
        transactionDetails = ""
        transactionSignature = ""
        lastTransactionData = nil
        verificationMessage = ""
    }
    
    func signTransaction() {
        guard let sendAmount = Double(amount) else {
            verificationMessage = "Invalid amount."
            return
        }
        if sendAmount <= 0 {
            verificationMessage = "Amount must be > 0."
            return
        }
        
        // Enforce balance rules based on consensus mechanism
        switch coordinator.consensusAlgorithm {
        case .pos:
            // Must not drop below 1.0
            if coordinator.balance - sendAmount < 1.0 {
                verificationMessage = ">1 needed to stake"
                return
            }
        default:
            // Must not drop below 0.0
            if coordinator.balance - sendAmount < 0.0 {
                verificationMessage = "Insufficient balance."
                return
            }
        }
        
        coordinator.balance -= sendAmount
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: "com.aravhawk.cryptolab.privatekey",
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let itemRef = item else {
            verificationMessage = "Error retrieving private key."
            // Roll back balance subtraction on error
            coordinator.balance += sendAmount
            return
        }
        let privateKey = itemRef as! SecKey
        
        let sender = deriveSenderAddress()
        let timestamp = "Timestamp: \(Date().timeIntervalSince1970)"
        let txString = "Sender: \(sender); Receiver: \(receiverAddress);" +
        " Amount: \(amount); \(timestamp)"
        pendingTransactionDetails = txString
        
        guard let transactionData = txString.data(using: .utf8) else { return }
        lastTransactionData = transactionData
        
        var error: Unmanaged<CFError>?
        guard let signatureData = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            transactionData as CFData,
            &error
        ) as Data? else {
            verificationMessage = "Error signing transaction."
            // Roll back balance if signing fails
            coordinator.balance += sendAmount
            return
        }
        
        transactionSignature = signatureData.map {
            String(format: "%02x", $0)
        }.joined()
        
        // Clear out any old verification message or details
        verificationMessage = ""
        transactionDetails = ""
    }
    
    func verifyTransaction() {
        guard
            let rawSignature = dataFromHexString(transactionSignature),
            let transactionData = lastTransactionData
        else {
            verificationMessage = "No transaction to verify."
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: "com.aravhawk.cryptolab.privatekey",
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let itemRef = item else {
            verificationMessage = "Could not retrieve key for verification."
            return
        }
        let privateKey = itemRef as! SecKey
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            verificationMessage = "Failed to derive public key."
            return
        }
        
        var error: Unmanaged<CFError>?
        let verified = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            transactionData as CFData,
            rawSignature as CFData,
            &error
        )
        
        if verified {
            verificationMessage = "Transaction Verified!"
            transactionDetails = pendingTransactionDetails
        } else {
            verificationMessage = "Transaction Verification Failed."
        }
    }
    
    func deriveSenderAddress() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: "com.aravhawk.cryptolab.privatekey",
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let itemRef = item else {
            return "Unknown"
        }
        let privateKey = itemRef as! SecKey
        guard let publicKeyData = getPublicKey(from: privateKey) else {
            return "Unknown"
        }
        return deriveAddress(from: publicKeyData) ?? "Unknown"
    }
    
    func getPublicKey(from privateKey: SecKey) -> Data? {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }
        return publicKeyData
    }
    
    func deriveAddress(from publicKey: Data) -> String? {
        let publicKeyWithoutPrefix = publicKey.dropFirst()
        let hashedPublicKey = SHA256.hash(data: publicKeyWithoutPrefix)
        let addressData = hashedPublicKey.suffix(20)
        return "0x" + addressData.map { String(format: "%02x", $0) }.joined()
    }
    
    func dataFromHexString(_ hex: String) -> Data? {
        var data = Data()
        var tempHex = hex
        if tempHex.count % 2 != 0 {
            tempHex = "0" + tempHex
        }
        while tempHex.count >= 2 {
            let c = String(tempHex.prefix(2))
            tempHex = String(tempHex.dropFirst(2))
            if let byte = UInt8(c, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        return data
    }
}

// MARK: - ReceivePopupView
struct ReceivePopupView: View {
    @Binding var showReceivePopup: Bool
    @State private var walletAddress: String = "Loading..."
    @State private var qrImage: Image? = nil
    private let qrGenerator = QRCodeGenerator()
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                Text("Receive")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Wallet Address:")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(walletAddress)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let qr = qrImage {
                    qr
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .padding()
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                Button("Copy Address") {
                    UIPasteboard.general.string = walletAddress
                }
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .frame(width: 300)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .shadow(radius: 8)
            
            Button {
                withAnimation {
                    showReceivePopup = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
        .onAppear {
            loadWalletAddressAndGenerateQR()
        }
    }
    
    private func loadWalletAddressAndGenerateQR() {
        let address = retrieveWalletAddress()
        walletAddress = address
        if !address.isEmpty {
            qrImage = qrGenerator.generateQRCode(from: address)
        }
    }
    
    private func retrieveWalletAddress() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: "com.aravhawk.cryptolab.privatekey",
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let itemRef = item else {
            return "No Wallet Found"
        }
        let privateKey = itemRef as! SecKey
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return "No Public Key"
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return "Error Exporting Public Key"
        }
        
        let pubKeyNoPrefix = publicKeyData.dropFirst()
        let hashedPubKey = SHA256.hash(data: pubKeyNoPrefix)
        let addressData = hashedPubKey.suffix(20)
        let addressHex = addressData.map { String(format: "%02x", $0) }.joined()
        return "0x" + addressHex
    }
}

// MARK: - QRCodeGenerator
fileprivate struct QRCodeGenerator {
    private let context = CIContext()
    private let filter = CIFilter(name: "CIQRCodeGenerator")!
    
    func generateQRCode(from string: String) -> Image? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage,
              let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return Image(uiImage: uiImage)
    }
}

// MARK: - simd_float4x4 extension
extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(x: columns.3.x, y: columns.3.y, z: columns.3.z)
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init?(hex: String) {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if cString.hasPrefix("#") {
            cString.removeFirst()
        }
        guard cString.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - ActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
