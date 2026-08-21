//
//  FeedbackView.swift
//  Transcription Keeper
//
//  Created by Michael Fluharty on 4/6/26.
//

import SwiftUI
import MessageUI

struct FeedbackView: View {
    let appName: String
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType: FeedbackType = .bug
    @State private var feedbackText = ""
    @State private var showingMailSheet = false
    @State private var showingMailUnavailable = false

    enum FeedbackType: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }

    private var deviceInfo: String {
        let device = UIDevice.current
        var sysinfo = utsname()
        uname(&sysinfo)
        let model = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingCString: $0) ?? "Unknown" }
        }
        let storage: String = {
            guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
                  let free = attrs[.systemFreeSize] as? Int64 else { return "Unknown" }
            return ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
        }()
        return """

        --- Device Info ---
        App: \(appName) \(version)
        Device: \(model)
        System: \(device.systemName) \(device.systemVersion)
        Storage Available: \(storage)
        Locale: \(Locale.current.identifier)
        """
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Feedback Type", selection: $feedbackType) {
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                TextEditor(text: $feedbackText)
                    .font(.system(size: 18))
                    .frame(minHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if feedbackText.isEmpty {
                            Text(feedbackType == .bug
                                 ? "Describe what happened and what you expected..."
                                 : "Describe the feature you'd like to see...")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    if MFMailComposeViewController.canSendMail() {
                        showingMailSheet = true
                    } else {
                        showingMailUnavailable = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                        Text("Send")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(feedbackText.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(feedbackText.isEmpty)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 18))
                }
            }
            .sheet(isPresented: $showingMailSheet) {
                MailComposeView(
                    subject: "\(appName) \(feedbackType.rawValue) — \(version)",
                    body: feedbackText + "\n\n" + deviceInfo,
                    recipient: "michael.fluharty@mac.com"
                )
            }
            .alert("Mail Not Available", isPresented: $showingMailUnavailable) {
                Button("OK") { }
            } message: {
                Text("Please configure a mail account in Settings, or email michael.fluharty@mac.com directly.")
            }
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipient: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
