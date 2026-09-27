import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var tokenInput = ""
    @State private var regionInput = ""
    @State private var showingRemoveConfirmation = false
    @State private var showingClearProgressConfirmation = false

    private var isRegionValid: Bool {
        regionInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: "^[A-Za-z]{2}$", options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("TMDB Connection") {
                    SecureField("TMDB v3 key or v4 Read Access Token", text: $tokenInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("A default API key is pre-configured. You can use your own key from TMDB if preferred.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Country code", text: $regionInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Text("Two-letter region for local streaming availability (auto-detected from device).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Get your own token from TMDB", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                        .font(.footnote.weight(.medium))
                }

                if let error = services.settings.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !services.settings.credential.isEmpty {
                    Section {
                        Button("Remove saved token", role: .destructive) {
                            showingRemoveConfirmation = true
                        }
                    }
                }

                Section("Streaming Sources") {
                    Toggle("Auto-select best server", isOn: Binding(
                        get: { services.streamingSources.autoSelectBestSource },
                        set: { services.streamingSources.setAutoSelect($0) }
                    ))
                    Text("Automatically picks the fastest, most reliable source based on health checks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Manual source selection (used when auto-select is off):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(services.streamingSources.sources) { source in
                        SourceToggleRow(source: source) { updatedSource in
                            services.streamingSources.updateSource(updatedSource)
                        }
                    }

                    if !services.streamingSources.watchProgress.isEmpty {
                        Section {
                            Button("Clear Watch Progress", role: .destructive) {
                                showingClearProgressConfirmation = true
                            }
                        }
                    }
                }

                Section("Availability") {
                    Label("Licensed provider listings are filtered by \(services.settings.regionCode).", systemImage: "globe")
                        .font(.footnote)
                    Text("Change the two-letter country code above to see the options available in another region.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("Streami uses TMDB for movie and television metadata. TMDB does not provide full-length video streams.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Streaming sources are third-party embed providers. Availability varies by region and content.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                } footer: {
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await services.settings.save(credential: tokenInput, region: regionInput) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isRegionValid)
                }
            }
            .onAppear {
                tokenInput = services.settings.credential
                regionInput = services.settings.regionCode
            }
            .confirmationDialog("Remove the saved TMDB token from this device?", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
                Button("Remove Token", role: .destructive) {
                    services.settings.clearCredential()
                    dismiss()
                }
            }
            .confirmationDialog("Clear all watch progress? This cannot be undone.", isPresented: $showingClearProgressConfirmation, titleVisibility: .visible) {
                Button("Clear All Progress", role: .destructive) {
                    services.streamingSources.clearAllProgress()
                }
            }
        }
    }
}

private struct SourceToggleRow: View {
    let source: StreamingSource
    let onUpdate: (StreamingSource) -> Void

    var body: some View {
        HStack {
            Image(systemName: source.icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.system(size: 16, weight: .medium))

                HStack(spacing: 8) {
                    if source.supportsMovies {
                        Label("Movies", systemImage: "film")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if source.supportsTV {
                        Label("TV", systemImage: "tv")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if source.supportsAnime {
                        Label("Anime", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let health = services.streamingSources.sourceHealthStatus[source.id] {
                        Label(health.isHealthy ? "✓ Healthy" : "⚠ Issues", systemImage: health.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(health.isHealthy ? .green : .orange)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { newValue in
                    var updated = source
                    updated.isEnabled = newValue
                    onUpdate(updated)
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}