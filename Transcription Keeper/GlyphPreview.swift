//
//  GlyphPreview.swift
//  Transcription Keeper
//
//  Preview file to see SF Symbol combination options
//

import SwiftUI

struct GlyphPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Text("Pick a Style")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)

                // OPTION 1: Horizontal row
                VStack(spacing: 8) {
                    Text("Option 1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.and.mic")
                        Image(systemName: "captions.bubble")
                        Image(systemName: "ear.and.waveform")
                    }
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // OPTION 2: Main + accent below
                VStack(spacing: 8) {
                    Text("Option 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 4) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 48))
                        HStack(spacing: 8) {
                            Image(systemName: "captions.bubble")
                            Image(systemName: "ear.and.waveform")
                        }
                        .font(.system(size: 20))
                        .foregroundStyle(.blue.opacity(0.6))
                    }
                    .foregroundStyle(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // OPTION 3: Overlaid/stacked
                VStack(spacing: 8) {
                    Text("Option 3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ZStack {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)
                        Image(systemName: "captions.bubble")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue.opacity(0.7))
                            .offset(x: 30, y: 20)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // OPTION 4: Just waveform.and.mic
                VStack(spacing: 8) {
                    Text("Option 4 (single)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // OPTION 5: Just captions.bubble
                VStack(spacing: 8) {
                    Text("Option 5 (single)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "captions.bubble")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // OPTION 6: Just ear.and.waveform
                VStack(spacing: 8) {
                    Text("Option 6 (single)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "ear.and.waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                Spacer(minLength: 40)
            }
            .padding()
        }
    }
}

#Preview {
    GlyphPreview()
}
