//
//  AboutView.swift
//  Transcription Keeper
//
//  Created by Michael Fluharty on 4/6/26.
//

import SwiftUI
import MessageUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingFeedback = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image("KnightMicWaveform")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcription Keeper")
                                .font(.system(size: 18, weight: .semibold))
                            Text(version)
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Label("Michael Lee Fluharty", systemImage: "person.fill")
                        .font(.system(size: 18))
                    Label("Engineered with Claude by Anthropic", systemImage: "cpu")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showingFeedback = true
                    } label: {
                        Label("Send Feedback", systemImage: "envelope.fill")
                            .font(.system(size: 18))
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 18))
                }
            }
            .sheet(isPresented: $showingFeedback) {
                FeedbackView(appName: "Transcription Keeper")
            }
        }
    }
}
