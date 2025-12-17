import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(currentPage == index ? Color(red: 0.4, green: 0.2, blue: 0.6) : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                TabView(selection: $currentPage) {
                    // Page 1: First Pairing
                    OnboardingPageView(
                        title: "First Time Setup",
                        steps: [
                            "Power on your device",
                            "Open Settings > Bluetooth on iPad",
                            "Tap 'CliQ Controller' to pair",
                            "Wait for 'Connected' status"
                        ]
                    )
                    .tag(0)
                    
                    // Page 2: Configure Buttons
                    OnboardingPageView(
                        title: "Configure Your Buttons",
                        steps: [
                            "Tap scan icon in this app",
                            "Select 'CliQ Controller' from list",
                            "Change button functions as needed",
                            "Settings save automatically"
                        ]
                    )
                    .tag(1)
                    
                    // Page 3: Daily Use
                    OnboardingPageView(
                        title: "Daily Use",
                        steps: [
                            "Check Settings > Bluetooth shows 'Connected'",
                            "Open Procreate and start drawing",
                            "Use this app only to change settings",
                            "Tap help icon for troubleshooting"
                        ]
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    if currentPage < 2 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .cornerRadius(8)
                    } else {
                        Button("Get Started") {
                            print("📱 Get Started button tapped")
                            showOnboarding = false
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            print("📱 🎉 OnboardingView appeared!")
        }
    }
}

struct OnboardingPageView: View {
    let title: String
    let steps: [String]
    
    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .frame(width: 24, height: 24)
                            
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text(step)
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}