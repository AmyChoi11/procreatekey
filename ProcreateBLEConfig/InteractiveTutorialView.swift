import SwiftUI

struct InteractiveTutorialView: View {
    @Binding var showTutorial: Bool
    @Binding var hasCompletedOnboarding: Bool
    
    // Namespace for matched geometry
    @Namespace private var tutorialNamespace
    
    @State private var currentStep = 0
    @State private var highlightFrame: CGRect = .zero
    
    let steps: [TutorialStep] = [
        TutorialStep(
            title: "First Time Setup",
            description: "Open Settings > Bluetooth on your iPad and pair \"XIAO Keyboard\"",
            highlightArea: nil,
            systemIcon: "bluetooth",
            actionRequired: false
        ),
        TutorialStep(
            title: "Connect Your Device",
            description: "Tap the scan icon to find your device",
            highlightArea: .scanButton,
            systemIcon: nil,
            actionRequired: true
        ),
        TutorialStep(
            title: "Configure Button 1",
            description: "Tap Button 1 (blue circle) to change its function. Try setting it to Undo!",
            highlightArea: .button1,
            systemIcon: nil,
            actionRequired: true
        ),
        TutorialStep(
            title: "Configure Button 2",
            description: "Tap Button 2 (red circle) to set it to Redo",
            highlightArea: .button2,
            systemIcon: nil,
            actionRequired: true
        ),
        TutorialStep(
            title: "Configure Scroll Wheel",
            description: "Tap the scroll wheel (purple pill) to control brush size",
            highlightArea: .scroll,
            systemIcon: nil,
            actionRequired: true
        ),
        TutorialStep(
            title: "Configure Combo Action",
            description: "Tap \"Buttons 1 + 2 Combo\" to set what happens when you press both buttons together",
            highlightArea: .combo,
            systemIcon: nil,
            actionRequired: true
        ),
        TutorialStep(
            title: "You're All Set!",
            description: "Open Procreate and start drawing. Your buttons are ready to use!",
            highlightArea: nil,
            systemIcon: "checkmark.circle",
            actionRequired: false
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Tap anywhere to advance (for highlight steps)
                        if steps[currentStep].highlightArea != nil {
                            nextStep()
                        }
                    }
                
                // Main content
                if let highlightArea = steps[currentStep].highlightArea {
                    // Interactive highlight mode
                    highlightView(for: highlightArea, in: geometry)
                } else {
                    // Info card mode
                    infoCardView()
                }
                
                // Skip button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: skipTutorial) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(20)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                    }
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func highlightView(for area: HighlightArea, in geometry: GeometryProxy) -> some View {
        let (position, size, isCircle) = getHighlightParameters(for: area, in: geometry)
        
        ZStack {
            // Highlight with glow
            Circle()
                .fill(Color.clear)
                .frame(width: size.width + 16, height: size.height + 16)
                .overlay(
                    RoundedRectangle(cornerRadius: isCircle ? (size.width + 16) / 2 : 12)
                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 3)
                        .shadow(color: Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.6), radius: 20, x: 0, y: 0)
                )
                .position(x: position.x + size.width / 2, y: position.y + size.height / 2)
            
            // Tooltip
            tooltipView(for: area, in: geometry, position: position, size: size)
        }
    }
    
    @ViewBuilder
    private func tooltipView(for area: HighlightArea, in geometry: GeometryProxy, position: CGPoint, size: CGSize) -> some View {
        let step = steps[currentStep]
        let tooltipWidth: CGFloat = geometry.size.width - 40
        let tooltipHeight: CGFloat = 160
        
        // Calculate if tooltip should go above or below
        let spaceAbove = position.y
        let spaceBelow = geometry.size.height - (position.y + size.height)
        let placeAbove = spaceAbove > spaceBelow && spaceAbove > 150
        
        let tooltipY = placeAbove ? position.y - tooltipHeight - 20 : position.y + size.height + 20
        
        VStack(alignment: .leading, spacing: 12) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(currentStep == index ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Title
            Text(step.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text(step.description)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineSpacing(2)
            
            // Tap instruction
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 18))
                Text("Tap to continue")
                    .font(.system(size: 13))
                    .italic()
            }
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: tooltipWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
        )
        .position(x: geometry.size.width / 2, y: tooltipY + tooltipHeight / 2)
        .onTapGesture {
            nextStep()
        }
    }
    
    @ViewBuilder
    private func infoCardView() -> some View {
        let step = steps[currentStep]
        
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(currentStep == index ? Color(red: 0.4, green: 0.2, blue: 0.6) : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Icon
                if let iconName = step.systemIcon {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: iconName)
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    }
                }
                
                // Title
                Text(step.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .multilineTextAlignment(.center)
                
                // Description
                Text(step.description)
                    .font(.system(size: 15))
                    .foregroundColor(.black.opacity(0.87))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                
                // Action button
                Button(action: nextStep) {
                    Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
    }
    
    private func getHighlightParameters(for area: HighlightArea, in geometry: GeometryProxy) -> (position: CGPoint, size: CGSize, isCircle: Bool) {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        
        switch area {
        case .scanButton:
            // Top-left scan button
            return (CGPoint(x: 8, y: 50), CGSize(width: 48, height: 48), false)
            
        case .button1:
            // Blue circle button (left side of controller)
            let centerX = screenWidth * 0.3
            let centerY = screenHeight * 0.25
            let diameter: CGFloat = 80
            return (CGPoint(x: centerX - diameter/2, y: centerY - diameter/2), CGSize(width: diameter, height: diameter), true)
            
        case .button2:
            // Red circle button (right side of controller)
            let centerX = screenWidth * 0.7
            let centerY = screenHeight * 0.25
            let diameter: CGFloat = 80
            return (CGPoint(x: centerX - diameter/2, y: centerY - diameter/2), CGSize(width: diameter, height: diameter), true)
            
        case .scroll:
            // Purple scroll wheel (center bottom of controller)
            let centerX = screenWidth * 0.5
            let centerY = screenHeight * 0.32
            let width: CGFloat = 120
            let height: CGFloat = 50
            return (CGPoint(x: centerX - width/2, y: centerY - height/2), CGSize(width: width, height: height), false)
            
        case .combo:
            // Combo button in the list (approximate position)
            let y = screenHeight * 0.7
            return (CGPoint(x: 20, y: y), CGSize(width: screenWidth - 40, height: 60), false)
        }
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            completeTutorial()
        }
    }
    
    private func skipTutorial() {
        completeTutorial()
    }
    
    private func completeTutorial() {
        hasCompletedOnboarding = true
        withAnimation {
            showTutorial = false
        }
    }
}

struct TutorialStep {
    let title: String
    let description: String
    let highlightArea: HighlightArea?
    let systemIcon: String?
    let actionRequired: Bool
}

enum HighlightArea {
    case scanButton
    case button1
    case button2
    case scroll
    case combo
}

// Preview
struct InteractiveTutorialView_Previews: PreviewProvider {
    static var previews: some View {
        InteractiveTutorialView(
            showTutorial: .constant(true),
            hasCompletedOnboarding: .constant(false)
        )
    }
}
