import SwiftUI

struct SettingsView: View {
    @State private var apiKey = Keychain.load(key: "openrouter_api_key")
    @AppStorage("system_prompt") private var systemPrompt = ""
    @AppStorage("background_theme") private var backgroundTheme = BackgroundTheme.sunshine.rawValue
    @AppStorage("custom_models") private var customModels = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenRouter API Key")
                            .font(.headline)

                        SecureField("OpenRouter API Key", text: $apiKey, prompt: Text("sk-or-..."))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onSubmit(saveAPIKey)

                        Text("Stored securely in your Mac's Keychain.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Background") {
                    HStack(spacing: 10) {
                        ForEach(BackgroundTheme.allCases) { theme in
                            Button {
                                backgroundTheme = theme.rawValue
                            } label: {
                                Circle()
                                    .fill(theme.color)
                                    .overlay(Circle().stroke(.primary.opacity(0.3), lineWidth: 1))
                                    .overlay {
                                        if backgroundTheme == theme.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(theme.usesLightText ? .white : .black)
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .help(theme.label)
                            .accessibilityLabel(theme.label)
                        }
                    }
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(height: 90)
                }

                Section("Custom Models") {
                    Text("Enter one OpenRouter model ID per line. Remove a line to remove that model.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $customModels)
                        .font(.system(size: 13, design: .monospaced))
                        .autocorrectionDisabled()
                        .accessibilityLabel("Custom OpenRouter model IDs")
                        .frame(height: 90)
                }
            }
            .formStyle(.grouped)
            .environment(\.defaultMinListHeaderHeight, 4)
            .padding(.top, 8)

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 460, height: 620)
        .onDisappear {
            saveAPIKey()
            customModels = CustomModels.parse(customModels).map(\.id).joined(separator: "\n")
        }
    }

    private func saveAPIKey() {
        Keychain.save(key: "openrouter_api_key", value: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
