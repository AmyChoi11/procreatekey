import SwiftUIimport SwiftUI



struct HelpView: View {struct HelpView: View {

    @Environment(\.dismiss) var dismiss    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var bleManager: BLEManager    @EnvironmentObject var bleManager: BLEManager

    @State private var isTutorialExpanded = false    @State private var selectedCategory: HelpCategory?

    @State private var isFaqExpanded = false    @State private var selectedIssue: HelpIssue?

    @State private var selectedCategory: HelpCategory?    @State private var showDetectedProblem: DetectedProblem?

    @State private var selectedIssue: HelpIssue?    

    @State private var showDetectedProblem: DetectedProblem?    var body: some View {

            NavigationView {

    var body: some View {            List {

        NavigationView {                if let problem = bleManager.detectedProblem {

            List {                    Section(header: Text("Detected Issue")) {

                // First Time Tutorial Section                        Button(action: { showDetectedProblem = problem }) {

                DisclosureGroup(                            HelpRowView(

                    isExpanded: $isTutorialExpanded,                                icon: "exclamationmark.triangle.fill",

                    content: {                                title: problem.title,

                        TutorialContentView()                                subtitle: "Tap for solution"

                    },                            )

                    label: {                        }

                        HelpSectionHeaderView(                        .foregroundColor(.orange)

                            icon: "graduationcap",                    }

                            title: "First Time Tutorial"                }

                        )                

                    }                Section(header: Text("All Issues")) {

                )                    Button(action: { selectedCategory = .connection }) {

                                        HelpRowView(

                // FAQ Section                            icon: "antenna.radiowaves.left.and.right",

                DisclosureGroup(                            title: "Connection Issues",

                    isExpanded: $isFaqExpanded,                            subtitle: "Cannot find or connect to device"

                    content: {                        )

                        VStack(spacing: 0) {                    }

                            if let problem = bleManager.detectedProblem {                    

                                Button(action: { showDetectedProblem = problem }) {                    Button(action: { selectedCategory = .functionality }) {

                                    HelpRowView(                        HelpRowView(

                                        icon: "exclamationmark.triangle.fill",                            icon: "hand.tap",

                                        title: problem.title,                            title: "Button Problems",

                                        subtitle: "Tap for solution"                            subtitle: "Buttons not working in Procreate"

                                    )                        )

                                }                    }

                                .foregroundColor(.orange)                    

                                .padding(.vertical, 8)                    Button(action: { selectedCategory = .configuration }) {

                                                        HelpRowView(

                                Divider()                            icon: "gearshape",

                            }                            title: "Configuration Issues",

                                                        subtitle: "Settings not saving or loading"

                            Button(action: { selectedCategory = .connection }) {                        )

                                HelpRowView(                    }

                                    icon: "antenna.radiowaves.left.and.right",                    

                                    title: "Connection Issues",                    Button(action: { selectedCategory = .bluetooth }) {

                                    subtitle: "Cannot find or connect to device"                        HelpRowView(

                                )                            icon: "antenna.radiowaves.left.and.right.slash",

                            }                            title: "Bluetooth Problems",

                            .padding(.vertical, 8)                            subtitle: "Pairing or permission issues"

                                                    )

                            Divider()                    }

                                            }

                            Button(action: { selectedCategory = .functionality }) {            }

                                HelpRowView(            .navigationTitle("Help")

                                    icon: "hand.tap",            .navigationBarTitleDisplayMode(.inline)

                                    title: "Button Problems",            .toolbar {

                                    subtitle: "Buttons not working in Procreate"                ToolbarItem(placement: .navigationBarTrailing) {

                                )                    Button("Done") { dismiss() }

                            }                }

                            .padding(.vertical, 8)            }

                                        .sheet(item: $selectedCategory) { category in

                            Divider()                IssueListView(category: category, selectedIssue: $selectedIssue)

                                        }

                            Button(action: { selectedCategory = .configuration }) {            .sheet(item: $selectedIssue) { issue in

                                HelpRowView(                SolutionView(issue: issue)

                                    icon: "gearshape",            }

                                    title: "Configuration Issues",            .sheet(item: $showDetectedProblem) { problem in

                                    subtitle: "Settings not saving or loading"                DetectedProblemView(problem: problem) {

                                )                    // Clear the detected problem after user views solution

                            }                    bleManager.detectedProblem = nil

                            .padding(.vertical, 8)                }

                                        }

                            Divider()            .onAppear {

                                            if let problem = bleManager.detectedProblem {

                            Button(action: { selectedCategory = .bluetooth }) {                    showDetectedProblem = problem

                                HelpRowView(                }

                                    icon: "antenna.radiowaves.left.and.right.slash",            }

                                    title: "Bluetooth Problems",        }

                                    subtitle: "Pairing or permission issues"    }

                                )}

                            }

                            .padding(.vertical, 8)struct HelpRowView: View {

                        }    let icon: String

                    },    let title: String

                    label: {    let subtitle: String

                        HelpSectionHeaderView(    

                            icon: "questionmark.circle",    var body: some View {

                            title: "FAQ"        HStack(spacing: 16) {

                        )            Image(systemName: icon)

                    }                .font(.system(size: 24))

                )                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

            }                .frame(width: 40)

            .navigationTitle("Help")            

            .navigationBarTitleDisplayMode(.inline)            VStack(alignment: .leading, spacing: 4) {

            .toolbar {                Text(title)

                ToolbarItem(placement: .navigationBarTrailing) {                    .font(.system(size: 16, weight: .semibold))

                    Button("Done") { dismiss() }                    .foregroundColor(.primary)

                }                

            }                Text(subtitle)

            .sheet(item: $selectedCategory) { category in                    .font(.system(size: 14))

                IssueListView(category: category, selectedIssue: $selectedIssue)                    .foregroundColor(.secondary)

            }            }

            .sheet(item: $selectedIssue) { issue in            

                SolutionView(issue: issue)            Spacer()

            }            

            .sheet(item: $showDetectedProblem) { problem in            Image(systemName: "chevron.right")

                DetectedProblemView(problem: problem) {                .foregroundColor(.gray)

                    bleManager.detectedProblem = nil        }

                }        .padding(.vertical, 8)

            }    }

            .onAppear {}

                if let problem = bleManager.detectedProblem {

                    showDetectedProblem = problem// MARK: - Categories and Issues

                }

            }enum HelpCategory: Identifiable {

        }    case connection

    }    case functionality

}    case configuration

    case bluetooth

// MARK: - Tutorial Content View    

    var id: String {

struct TutorialContentView: View {        switch self {

    var body: some View {        case .connection: return "connection"

        VStack(alignment: .leading, spacing: 24) {        case .functionality: return "functionality"

            TutorialStepView(        case .configuration: return "configuration"

                title: "First Time Setup",        case .bluetooth: return "bluetooth"

                steps: [        }

                    "Power on your device",    }

                    "Open Settings > Bluetooth on iPad",    

                    "Tap XIAO Keyboard to pair",    var title: String {

                    "Wait for Connected status"        switch self {

                ]        case .connection: return "Connection Issues"

            )        case .functionality: return "Button Problems"

                    case .configuration: return "Configuration Issues"

            Divider()        case .bluetooth: return "Bluetooth Problems"

                    }

            TutorialStepView(    }

                title: "Configure Your Buttons",    

                steps: [    var issues: [HelpIssue] {

                    "Tap scan icon in this app",        switch self {

                    "Select XIAO Keyboard from list",        case .connection:

                    "Change button functions as needed",            return [.cannotFindDevice, .deviceNotInApp, .appDisconnects]

                    "Settings save automatically"        case .functionality:

                ]            return [.buttonsNotWorking, .dialNotWorking]

            )        case .configuration:

                        return [.settingsNotSaving, .settingsNotLoading]

            Divider()        case .bluetooth:

                        return [.bluetoothOff, .noPermission]

            TutorialStepView(        }

                title: "Daily Use",    }

                steps: [}

                    "Check Settings > Bluetooth shows Connected",

                    "Open Procreate and start drawing",enum HelpIssue: Identifiable {

                    "Use this app only to change settings",    case cannotFindDevice

                    "Tap help icon for troubleshooting"    case deviceNotInApp

                ]    case appDisconnects

            )    case buttonsNotWorking

        }    case dialNotWorking

        .padding(.vertical, 8)    case settingsNotSaving

    }    case settingsNotLoading

}    case bluetoothOff

    case noPermission

struct TutorialStepView: View {    

    let title: String    var id: String {

    let steps: [String]        switch self {

            case .cannotFindDevice: return "cannotFind"

    var body: some View {        case .deviceNotInApp: return "notInApp"

        VStack(alignment: .leading, spacing: 12) {        case .appDisconnects: return "disconnects"

            Text(title)        case .buttonsNotWorking: return "buttonsNotWorking"

                .font(.system(size: 18, weight: .bold))        case .dialNotWorking: return "dialNotWorking"

                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))        case .settingsNotSaving: return "notSaving"

                    case .settingsNotLoading: return "notLoading"

            VStack(alignment: .leading, spacing: 8) {        case .bluetoothOff: return "btOff"

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in        case .noPermission: return "noPermission"

                    HStack(alignment: .top, spacing: 12) {        }

                        Text("\(index + 1)")    }

                            .font(.system(size: 12, weight: .bold))    

                            .foregroundColor(.white)    var title: String {

                            .frame(width: 24, height: 24)        switch self {

                            .background(Color(red: 0.4, green: 0.2, blue: 0.6))        case .cannotFindDevice: return "Cannot find device when scanning"

                            .cornerRadius(12)        case .deviceNotInApp: return "Device in Settings but not in app"

                                case .appDisconnects: return "App disconnects randomly"

                        Text(step)        case .buttonsNotWorking: return "Physical buttons do nothing"

                            .font(.system(size: 15))        case .dialNotWorking: return "Dial does not change brush size"

                            .foregroundColor(.primary)        case .settingsNotSaving: return "Settings revert after closing app"

                            .fixedSize(horizontal: false, vertical: true)        case .settingsNotLoading: return "App shows no configuration"

                    }        case .bluetoothOff: return "Bluetooth is turned off"

                }        case .noPermission: return "No Bluetooth permission"

            }        }

        }    }

    }    

}    var steps: [String] {

        switch self {

// MARK: - Section Header View        case .cannotFindDevice:

            return [

struct HelpSectionHeaderView: View {                "Turn device off using power button",

    let icon: String                "Wait 10 seconds",

    let title: String                "Turn device back on",

                    "Move iPad within 3 feet of device",

    var body: some View {                "Open Settings > Bluetooth and verify it is ON",

        HStack(spacing: 12) {                "Return to app and tap scan icon",

            Image(systemName: icon)                "Wait 10 seconds for device to appear"

                .font(.system(size: 24))            ]

                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))            

                .frame(width: 32)        case .deviceNotInApp:

                        return [

            Text(title)                "Check Settings > Bluetooth shows 'XIAO Keyboard Connected'",

                .font(.system(size: 20, weight: .bold))                "In this app, tap scan icon",

                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                "Device should appear in list",

        }                "Tap device to connect"

        .padding(.vertical, 4)            ]

    }            

}        case .appDisconnects:

            return [

struct HelpRowView: View {                "Keep app in foreground while configuring",

    let icon: String                "Complete all changes quickly",

    let title: String                "Tap X button to disconnect properly",

    let subtitle: String                "Close app after disconnecting",

                    "Keyboard continues working in Settings"

    var body: some View {            ]

        HStack(spacing: 16) {            

            Image(systemName: icon)        case .buttonsNotWorking:

                .font(.system(size: 24))            return [

                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                "Open Settings > Bluetooth",

                .frame(width: 40)                "Find 'XIAO Keyboard' in MY DEVICES",

                            "Status must show 'Connected'",

            VStack(alignment: .leading, spacing: 4) {                "If 'Not Connected', tap device name",

                Text(title)                "Wait for 'Connected' status",

                    .font(.system(size: 16, weight: .semibold))                "Open Procreate and test buttons"

                    .foregroundColor(.primary)            ]

                            

                Text(subtitle)        case .dialNotWorking:

                    .font(.system(size: 14))            return [

                    .foregroundColor(.secondary)                "Open this app and connect to device",

            }                "Check 'Dial' setting shows 'Brush Size 10%' or 'Brush Size 5%'",

                            "In Procreate, select brush tool",

            Spacer()                "Rotate dial clockwise to increase size",

                            "Rotate dial counter-clockwise to decrease size"

            Image(systemName: "chevron.right")            ]

                .foregroundColor(.gray)            

        }        case .settingsNotSaving:

    }            return [

}                "Wait for 'Config saved successfully' message",

                "Wait 3 seconds before testing",

// MARK: - Categories and Issues                "Open Procreate and test button",

                "If still wrong, repeat configuration",

enum HelpCategory: Identifiable {                "Settings save automatically to device memory"

    case connection            ]

    case functionality            

    case configuration        case .settingsNotLoading:

    case bluetooth            return [

                    "Wait 5 seconds after connection",

    var id: String {                "Tap X button to disconnect",

        switch self {                "Wait 3 seconds",

        case .connection: return "connection"                "Tap scan icon and reconnect",

        case .functionality: return "functionality"                "Device sends configuration automatically"

        case .configuration: return "configuration"            ]

        case .bluetooth: return "bluetooth"            

        }        case .bluetoothOff:

    }            return [

                    "Open Settings app",

    var title: String {                "Tap Bluetooth",

        switch self {                "Toggle Bluetooth switch to ON",

        case .connection: return "Connection Issues"                "Return to this app",

        case .functionality: return "Button Problems"                "Tap scan icon"

        case .configuration: return "Configuration Issues"            ]

        case .bluetooth: return "Bluetooth Problems"            

        }        case .noPermission:

    }            return [

                    "Open Settings app",

    var issues: [HelpIssue] {                "Tap Privacy & Security",

        switch self {                "Tap Bluetooth",

        case .connection:                "Find 'eSketch Shortcuts' in list",

            return [.cannotFindDevice, .deviceNotInApp, .appDisconnects]                "Toggle switch to ON",

        case .functionality:                "Return to this app",

            return [.buttonsNotWorking, .dialNotWorking]                "Tap scan icon"

        case .configuration:            ]

            return [.settingsNotSaving, .settingsNotLoading]        }

        case .bluetooth:    }

            return [.bluetoothOff, .noPermission]}

        }

    }// MARK: - Issue List View

}

struct IssueListView: View {

enum HelpIssue: Identifiable {    let category: HelpCategory

    case cannotFindDevice    @Binding var selectedIssue: HelpIssue?

    case deviceNotInApp    @Environment(\.dismiss) var dismiss

    case appDisconnects    

    case buttonsNotWorking    var body: some View {

    case dialNotWorking        NavigationView {

    case settingsNotSaving            List(category.issues) { issue in

    case settingsNotLoading                Button(action: {

    case bluetoothOff                    selectedIssue = issue

    case noPermission                    dismiss()

                    }) {

    var id: String {                    HStack {

        switch self {                        Text(issue.title)

        case .cannotFindDevice: return "cannotFind"                            .foregroundColor(.primary)

        case .deviceNotInApp: return "notInApp"                            .fixedSize(horizontal: false, vertical: true)

        case .appDisconnects: return "disconnects"                        Spacer()

        case .buttonsNotWorking: return "buttonsNotWorking"                        Image(systemName: "chevron.right")

        case .dialNotWorking: return "dialNotWorking"                            .foregroundColor(.gray)

        case .settingsNotSaving: return "notSaving"                    }

        case .settingsNotLoading: return "notLoading"                    .padding(.vertical, 8)

        case .bluetoothOff: return "btOff"                }

        case .noPermission: return "noPermission"            }

        }            .navigationTitle(category.title)

    }            .navigationBarTitleDisplayMode(.inline)

                .toolbar {

    var title: String {                ToolbarItem(placement: .navigationBarTrailing) {

        switch self {                    Button("Cancel") { dismiss() }

        case .cannotFindDevice: return "Cannot find device when scanning"                }

        case .deviceNotInApp: return "Device in Settings but not in app"            }

        case .appDisconnects: return "App disconnects randomly"        }

        case .buttonsNotWorking: return "Physical buttons do nothing"    }

        case .dialNotWorking: return "Dial does not change brush size"}

        case .settingsNotSaving: return "Settings revert after closing app"

        case .settingsNotLoading: return "App shows no configuration"// MARK: - Solution View

        case .bluetoothOff: return "Bluetooth is turned off"

        case .noPermission: return "No Bluetooth permission"struct SolutionView: View {

        }    let issue: HelpIssue

    }    @Environment(\.dismiss) var dismiss

        

    var steps: [String] {    var body: some View {

        switch self {        NavigationView {

        case .cannotFindDevice:            ScrollView {

            return [                VStack(alignment: .leading, spacing: 24) {

                "Turn device off using power button",                    Text(issue.title)

                "Wait 10 seconds",                        .font(.system(size: 24, weight: .bold))

                "Turn device back on",                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

                "Move iPad within 3 feet of device",                        .padding(.horizontal)

                "Open Settings > Bluetooth and verify it is ON",                        .padding(.top)

                "Return to app and tap scan icon",                    

                "Wait 10 seconds for device to appear"                    VStack(alignment: .leading, spacing: 16) {

            ]                        ForEach(Array(issue.steps.enumerated()), id: \.offset) { index, step in

                                        HStack(alignment: .top, spacing: 12) {

        case .deviceNotInApp:                                Text("\(index + 1)")

            return [                                    .font(.system(size: 14, weight: .bold))

                "Check Settings > Bluetooth shows 'XIAO Keyboard Connected'",                                    .foregroundColor(.white)

                "In this app, tap scan icon",                                    .frame(width: 24, height: 24)

                "Device should appear in list",                                    .background(Color(red: 0.4, green: 0.2, blue: 0.6))

                "Tap device to connect"                                    .cornerRadius(12)

            ]                                

                                            Text(step)

        case .appDisconnects:                                    .font(.system(size: 16))

            return [                                    .foregroundColor(.primary)

                "Keep app in foreground while configuring",                                    .fixedSize(horizontal: false, vertical: true)

                "Complete all changes quickly",                            }

                "Tap X button to disconnect properly",                        }

                "Close app after disconnecting",                    }

                "Keyboard continues working in Settings"                    .padding(.horizontal)

            ]                    

                                Spacer(minLength: 40)

        case .buttonsNotWorking:                }

            return [            }

                "Open Settings > Bluetooth",            .background(Color(red: 0.95, green: 0.95, blue: 0.97))

                "Find 'XIAO Keyboard' in MY DEVICES",            .navigationBarTitleDisplayMode(.inline)

                "Status must show 'Connected'",            .toolbar {

                "If 'Not Connected', tap device name",                ToolbarItem(placement: .navigationBarTrailing) {

                "Wait for 'Connected' status",                    Button("Done") { dismiss() }

                "Open Procreate and test buttons"                }

            ]            }

                    }

        case .dialNotWorking:    }

            return [}

                "Open this app and connect to device",

                "Check 'Dial' setting shows 'Brush Size 10%' or 'Brush Size 5%'",// MARK: - Detected Problem View

                "In Procreate, select brush tool",

                "Rotate dial clockwise to increase size",struct DetectedProblemView: View {

                "Rotate dial counter-clockwise to decrease size"    let problem: DetectedProblem

            ]    var onDismiss: (() -> Void)? = nil

                @Environment(\.dismiss) var dismiss

        case .settingsNotSaving:    

            return [    var body: some View {

                "Wait for 'Config saved successfully' message",        NavigationView {

                "Wait 3 seconds before testing",            ScrollView {

                "Open Procreate and test button",                VStack(alignment: .leading, spacing: 24) {

                "If still wrong, repeat configuration",                    HStack {

                "Settings save automatically to device memory"                        Image(systemName: "exclamationmark.triangle.fill")

            ]                            .font(.system(size: 40))

                                        .foregroundColor(.orange)

        case .settingsNotLoading:                        

            return [                        Text(problem.title)

                "Wait 5 seconds after connection",                            .font(.system(size: 24, weight: .bold))

                "Tap X button to disconnect",                            .foregroundColor(.primary)

                "Wait 3 seconds",                    }

                "Tap scan icon and reconnect",                    .padding(.horizontal)

                "Device sends configuration automatically"                    .padding(.top)

            ]                    

                                VStack(alignment: .leading, spacing: 16) {

        case .bluetoothOff:                        ForEach(Array(problem.steps.enumerated()), id: \.offset) { index, step in

            return [                            HStack(alignment: .top, spacing: 12) {

                "Open Settings app",                                Text("\(index + 1)")

                "Tap Bluetooth",                                    .font(.system(size: 14, weight: .bold))

                "Toggle Bluetooth switch to ON",                                    .foregroundColor(.white)

                "Return to this app",                                    .frame(width: 24, height: 24)

                "Tap scan icon"                                    .background(Color.orange)

            ]                                    .cornerRadius(12)

                                            

        case .noPermission:                                Text(step)

            return [                                    .font(.system(size: 16))

                "Open Settings app",                                    .foregroundColor(.primary)

                "Tap Privacy & Security",                                    .fixedSize(horizontal: false, vertical: true)

                "Tap Bluetooth",                            }

                "Find 'eSketch Shortcuts' in list",                        }

                "Toggle switch to ON",                    }

                "Return to this app",                    .padding(.horizontal)

                "Tap scan icon"                    

            ]                    Spacer(minLength: 40)

        }                }

    }            }

}            .background(Color(red: 0.95, green: 0.95, blue: 0.97))

            .navigationBarTitleDisplayMode(.inline)

// MARK: - Issue List View            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {

struct IssueListView: View {                    Button("Done") { dismiss() }

    let category: HelpCategory                }

    @Binding var selectedIssue: HelpIssue?            }

    @Environment(\.dismiss) var dismiss            .onDisappear {

                    onDismiss?()

    var body: some View {            }

        NavigationView {        }

            List(category.issues) { issue in    }

                Button(action: {}

                    selectedIssue = issue
                    dismiss()
                }) {
                    HStack {
                        Text(issue.title)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(issue.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .padding(.horizontal)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(issue.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .cornerRadius(12)
                                
                                Text(step)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Detected Problem View

struct DetectedProblemView: View {
    let problem: DetectedProblem
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text(problem.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(problem.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.orange)
                                    .cornerRadius(12)
                                
                                Text(step)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onDisappear {
                onDismiss?()
            }
        }
    }
}
