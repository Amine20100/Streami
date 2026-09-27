import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var tokenInput = ""
    @State private var regionInput = ""
    @State private var showingRemoveConfirmation = false

    private var isRegionValid: Bool {
        regionInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: "^[A-Za-z]{2}$", options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("TMDB Connection") {
                    SecureField("TMDB v3 key or v4 Read Access Token", text: $tokenInput, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Paste your TMDB v3 API key or v4 Read Access Token. It is stored securely in this device's Keychain.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Country code", text: $regionInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Text("Two-letter region for local streaming availability, such as US or GB.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Get a token from TMDB", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
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
        }
    }
}