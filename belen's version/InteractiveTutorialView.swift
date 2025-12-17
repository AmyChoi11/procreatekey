import SwiftUI

struct InteractiveTutorialView: View {
    @Binding var showTutorial: Bool
    @Binding var hasCompletedOnboarding: Bool
    
    // Frame tracking from ContentView
    let scanButtonFrame: CGRect
    let button1Frame: CGRect
    let button2Frame: CGRect
    let scrollFrame: CGRect
    let comboFrame: CGRect
    let clickScrollFrame: CGRect
    
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
            title: "Configure Click on Scroll",
            description: "Tap the Click on Scroll button (purple pill with hand icon) to set what happens when you click the scroll wheel",
            highlightArea: .clickScroll,
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
            title: "3-Position Switch",
            description: "Your device has a 3-position switch that lets you switch between Custom 1, 2, and 3 presets. Configure each preset by moving the switch and saving different settings!",
            highlightArea: nil,
            systemIcon: "switch.2",
            actionRequired: false
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
            // Capture the overlay's position in global coordinates to calculate offset
            GeometryReader { overlayGeometry in
                let overlayGlobalFrame = overlayGeometry.frame(in: .global)
                
                ZStack {
                    // Dark overlay (85% like Flutter) with cutouts
                    ZStack {
                        Color.black.opacity(0.85)
                            .ignoresSafeArea()
                        
                        // Main content
                        if let highlightArea = steps[currentStep].highlightArea {
                            // Interactive highlight mode - pass the offset to adjust coordinates
                            highlightView(for: highlightArea, in: geometry, overlayOffset: overlayGlobalFrame.origin)
                        }
                    }
                    .compositingGroup()
                    .onTapGesture {
                        if steps[currentStep].highlightArea != nil {
                            nextStep()
                        }
                    }
                    
                    // Info card mode (separate from overlay)
                    if steps[currentStep].highlightArea == nil {
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
                                    .background(Color.white.opacity(0.3))
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
    }
    
    @ViewBuilder
    private func highlightView(for area: HighlightArea, in geometry: GeometryProxy, overlayOffset: CGPoint) -> some View {
        let (position, size, isCircle) = getHighlightParameters(for: area, in: geometry, overlayOffset: overlayOffset)
        
        ZStack {
            // Create cutout mask for the dark overlay by drawing the shape
            if isCircle {
                Circle()
                    .fill(Color.black)
                    .frame(width: size.width, height: size.height)
                    .position(x: position.x + size.width / 2, y: position.y + size.height / 2)
                    .blendMode(.destinationOut)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(width: size.width, height: size.height)
                    .position(x: position.x + size.width / 2, y: position.y + size.height / 2)
                    .blendMode(.destinationOut)
            }
            
            // Highlight border with glow
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
                .shadow(color: .black.opacity(1.0), radius: 15, x: 0, y: 5)
        )
        .position(x: geometry.size.width / 2, y: tooltipY + tooltipHeight / 2)
        .onTapGesture {
            nextStep()
        }
    }
    
    @ViewBuilder
    private func infoCardView() -> some View {
        let step = steps[currentStep]
        
        // First page - full screen and clickable
        if currentStep == 0 {
            ZStack {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Icon
                    if let iconName = step.systemIcon {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: iconName)
                                .font(.system(size: 60))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        }
                    }
                    
                    // Title
                    Text(step.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    Text(step.description)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Tap to continue hint
                    VStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Tap anywhere to continue")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 60)
                }
            }
            .onTapGesture {
                nextStep()
            }
        } else {
            // Other pages - card view at bottom
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
    }
    
    private func getHighlightParameters(for area: HighlightArea, in geometry: GeometryProxy, overlayOffset: CGPoint) -> (position: CGPoint, size: CGSize, isCircle: Bool) {
        switch area {
        case .scanButton:
            // Use actual scan button frame dimensions
            let padding: CGFloat = 8
            // Convert from global coordinates to overlay-local coordinates
            let localX = scanButtonFrame.midX - overlayOffset.x
            let localY = scanButtonFrame.midY - overlayOffset.y
            let width = scanButtonFrame.width + padding * 2
            let height = scanButtonFrame.height + padding * 2
            // Position is top-left corner for the frame calculation
            return (
                CGPoint(x: localX - width / 2, y: localY - height / 2),
                CGSize(width: width, height: height),
                false
            )
            
        case .button1:
            // Use actual button1 frame - it's a circle, so use diameter
            let padding: CGFloat = 10
            let localX = button1Frame.midX - overlayOffset.x
            let localY = button1Frame.midY - overlayOffset.y
            let diameter = button1Frame.width + padding * 2
            return (
                CGPoint(x: localX - diameter / 2, y: localY - diameter / 2),
                CGSize(width: diameter, height: diameter),
                true
            )
            
        case .button2:
            // Use actual button2 frame - it's a circle, so use diameter
            let padding: CGFloat = 10
            let localX = button2Frame.midX - overlayOffset.x
            let localY = button2Frame.midY - overlayOffset.y
            let diameter = button2Frame.width + padding * 2
            return (
                CGPoint(x: localX - diameter / 2, y: localY - diameter / 2),
                CGSize(width: diameter, height: diameter),
                true
            )
            
        case .scroll:
            // Use actual scroll frame - it's a capsule/pill shape
            let padding: CGFloat = 10
            let localX = scrollFrame.midX - overlayOffset.x
            let localY = scrollFrame.midY - overlayOffset.y
            let width = scrollFrame.width + padding * 2
            let height = scrollFrame.height + padding * 2
            return (
                CGPoint(x: localX - width / 2, y: localY - height / 2),
                CGSize(width: width, height: height),
                false
            )
            
        case .clickScroll:
            // Use actual clickScroll frame - it's a capsule/pill shape
            let padding: CGFloat = 10
            let localX = clickScrollFrame.midX - overlayOffset.x
            let localY = clickScrollFrame.midY - overlayOffset.y
            let width = clickScrollFrame.width + padding * 2
            let height = clickScrollFrame.height + padding * 2
            return (
                CGPoint(x: localX - width / 2, y: localY - height / 2),
                CGSize(width: width, height: height),
                false
            )
            
        case .combo:
            // Use actual combo button frame
            let padding: CGFloat = 8
            let localX = comboFrame.midX - overlayOffset.x
            let localY = comboFrame.midY - overlayOffset.y
            let width = comboFrame.width + padding * 2
            let height = comboFrame.height + padding * 2
            return (
                CGPoint(x: localX - width / 2, y: localY - height / 2),
                CGSize(width: width, height: height),
                false
            )
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
    case clickScroll
    case combo
}

// Preview
struct InteractiveTutorialView_Previews: PreviewProvider {
    static var previews: some View {
        InteractiveTutorialView(
            showTutorial: .constant(true),
            hasCompletedOnboarding: .constant(false),
            scanButtonFrame: CGRect(x: 20, y: 50, width: 100, height: 40),
            button1Frame: CGRect(x: 100, y: 300, width: 80, height: 80),
            button2Frame: CGRect(x: 250, y: 300, width: 80, height: 80),
            scrollFrame: CGRect(x: 180, y: 380, width: 60, height: 100),
            comboFrame: CGRect(x: 20, y: 500, width: 350, height: 60),
            clickScrollFrame: CGRect(x: 150, y: 450, width: 60, height: 100)
        )
    }
}
