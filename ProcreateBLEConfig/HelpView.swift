import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bleManager: BLEManager
    @State private var selectedCategory: HelpCategory?
    @State private var selectedIssue: HelpIssue?
    @State private var showDetectedProblem: DetectedProblem?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let problem = bleManager.detectedProblem {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Detected Issue")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                Button(action: { showDetectedProblem = problem }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.orange)
                                            .frame(width: 40)
                                        
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(problem.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Text("Tap for solution")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Issues")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                HelpCategoryCard(
                                    icon: "antenna.radiowaves.left.and.right",
                                    title: "Connection Issues",
                                    subtitle: "Cannot find or connect to device"
                                ) {
                                    selectedCategory = .connection
                                }
                                
                                HelpCategoryCard(
                                    icon: "hand.tap",
                                    title: "Button Problems",
                                    subtitle: "Buttons not working in Procreate"
                                ) {
                                    selectedCategory = .functionality
                                }
                                
                                HelpCategoryCard(
                                    icon: "gearshape",
                                    title: "Configuration Issues",
                                    subtitle: "Settings not saving or loading"
                                ) {
                                    selectedCategory = .configuration
                                }
                                
                                HelpCategoryCard(
                                    icon: "antenna.radiowaves.left.and.right.slash",
                                    title: "Bluetooth Problems",
                                    subtitle: "Pairing or permission issues"
                                ) {
                                    selectedCategory = .bluetooth
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(item: $selectedCategory) { category in
                IssueListView(category: category, selectedIssue: $selectedIssue)
            }
            .sheet(item: $selectedIssue) { issue in
                SolutionView(issue: issue)
            }
            .sheet(item: $showDetectedProblem) { problem in
                DetectedProblemView(problem: problem)
            }
            .onAppear {
                if let problem = bleManager.detectedProblem {
                    showDetectedProblem = problem
                }
            }
        }
    }
}

// MARK: - Help Category Card (matching main app style)
struct HelpCategoryCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

struct HelpRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Categories and Issues

enum HelpCategory: Identifiable {
    case connection
    case functionality
    case configuration
    case bluetooth
    
    var id: String {
        switch self {
        case .connection: return "connection"
        case .functionality: return "functionality"
        case .configuration: return "configuration"
        case .bluetooth: return "bluetooth"
        }
    }
    
    var title: String {
        switch self {
        case .connection: return "Connection Issues"
        case .functionality: return "Button Problems"
        case .configuration: return "Configuration Issues"
        case .bluetooth: return "Bluetooth Problems"
        }
    }
    
    var issues: [HelpIssue] {
        switch self {
        case .connection:
            return [.cannotFindDevice, .deviceNotInApp, .appDisconnects]
        case .functionality:
            return [.buttonsNotWorking, .dialNotWorking]
        case .configuration:
            return [.settingsNotSaving, .settingsNotLoading]
        case .bluetooth:
            return [.bluetoothOff, .noPermission]
        }
    }
}

enum HelpIssue: Identifiable {
    case cannotFindDevice
    case deviceNotInApp
    case appDisconnects
    case buttonsNotWorking
    case dialNotWorking
    case settingsNotSaving
    case settingsNotLoading
    case bluetoothOff
    case noPermission
    
    var id: String {
        switch self {
        case .cannotFindDevice: return "cannotFind"
        case .deviceNotInApp: return "notInApp"
        case .appDisconnects: return "disconnects"
        case .buttonsNotWorking: return "buttonsNotWorking"
        case .dialNotWorking: return "dialNotWorking"
        case .settingsNotSaving: return "notSaving"
        case .settingsNotLoading: return "notLoading"
        case .bluetoothOff: return "btOff"
        case .noPermission: return "noPermission"
        }
    }
    
    var title: String {
        switch self {
        case .cannotFindDevice: return "Cannot find device when scanning"
        case .deviceNotInApp: return "Device in Settings but not in app"
        case .appDisconnects: return "App disconnects randomly"
        case .buttonsNotWorking: return "Physical buttons do nothing"
        case .dialNotWorking: return "Dial does not change brush size"
        case .settingsNotSaving: return "Settings revert after closing app"
        case .settingsNotLoading: return "App shows no configuration"
        case .bluetoothOff: return "Bluetooth is turned off"
        case .noPermission: return "No Bluetooth permission"
        }
    }
    
    var steps: [String] {
        switch self {
        case .cannotFindDevice:
            return [
                "Turn device off using power button",
                "Wait 10 seconds",
                "Turn device back on",
                "Move iPad within 3 feet of device",
                "Open Settings > Bluetooth and verify it is ON",
                "Return to app and tap scan icon",
                "Wait 10 seconds for device to appear"
            ]
            
        case .deviceNotInApp:
            return [
                "Check Settings > Bluetooth shows 'XIAO Keyboard Connected'",
                "In this app, tap scan icon",
                "Device should appear in list",
                "Tap device to connect"
            ]
            
        case .appDisconnects:
            return [
                "Keep app in foreground while configuring",
                "Complete all changes quickly",
                "Tap X button to disconnect properly",
                "Close app after disconnecting",
                "Keyboard continues working in Settings"
            ]
            
        case .buttonsNotWorking:
            return [
                "Open Settings > Bluetooth",
                "Find 'XIAO Keyboard' in MY DEVICES",
                "Status must show 'Connected'",
                "If 'Not Connected', tap device name",
                "Wait for 'Connected' status",
                "Open Procreate and test buttons"
            ]
            
        case .dialNotWorking:
            return [
                "Open this app and connect to device",
                "Check 'Dial' setting shows 'Brush Size 10%' or 'Brush Size 5%'",
                "In Procreate, select brush tool",
                "Rotate dial clockwise to increase size",
                "Rotate dial counter-clockwise to decrease size"
            ]
            
        case .settingsNotSaving:
            return [
                "Wait for 'Config saved successfully' message",
                "Wait 3 seconds before testing",
                "Open Procreate and test button",
                "If still wrong, repeat configuration",
                "Settings save automatically to device memory"
            ]
            
        case .settingsNotLoading:
            return [
                "Wait 5 seconds after connection",
                "Tap X button to disconnect",
                "Wait 3 seconds",
                "Tap scan icon and reconnect",
                "Device sends configuration automatically"
            ]
            
        case .bluetoothOff:
            return [
                "Open Settings app",
                "Tap Bluetooth",
                "Toggle Bluetooth switch to ON",
                "Return to this app",
                "Tap scan icon"
            ]
            
        case .noPermission:
            return [
                "Open Settings app",
                "Tap Privacy & Security",
                "Tap Bluetooth",
                "Find 'eSketch Shortcuts' in list",
                "Toggle switch to ON",
                "Return to this app",
                "Tap scan icon"
            ]
        }
    }
}

// MARK: - Issue List View

struct IssueListView: View {
    let category: HelpCategory
    @Binding var selectedIssue: HelpIssue?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(category.issues) { issue in
                            Button(action: {
                                selectedIssue = issue
                                dismiss()
                            }) {
                                HStack {
                                    Text(issue.title)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Solution View

struct SolutionView: View {
    let issue: HelpIssue
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(issue.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            .padding(.horizontal)
                            .padding(.top)
                        
                        VStack(spacing: 16) {
                            ForEach(Array(issue.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        .cornerRadius(14)
                                    
                                    Text(step)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Detected Problem View

struct DetectedProblemView: View {
    let problem: DetectedProblem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                            
                            Text(problem.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        VStack(spacing: 16) {
                            ForEach(Array(problem.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.orange)
                                        .cornerRadius(14)
                                    
                                    Text(step)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}