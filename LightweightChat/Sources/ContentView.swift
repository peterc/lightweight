import SwiftUI

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case sunshine
    case butter
    case softGold
    case warmPeach
    case financialTimes
    case powderBlue
    case skyBlue
    case lavender
    case white
    case darkGray
    case black

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunshine: "Sunshine (Default)"
        case .butter: "Butter"
        case .softGold: "Soft Gold"
        case .warmPeach: "Warm Peach"
        case .financialTimes: "Financial Times"
        case .powderBlue: "Powder Blue"
        case .skyBlue: "Sky Blue"
        case .lavender: "Lavender"
        case .white: "White"
        case .darkGray: "Dark Gray"
        case .black: "Black"
        }
    }

    var color: Color {
        switch self {
        case .sunshine: Color(red: 1.0, green: 0.93, blue: 0.55)
        case .butter: Color(red: 1.0, green: 0.96, blue: 0.72)
        case .softGold: Color(red: 0.96, green: 0.83, blue: 0.40)
        case .warmPeach: Color(red: 1.0, green: 0.84, blue: 0.71)
        case .financialTimes: Color(red: 252.0 / 255.0, green: 208.0 / 255.0, blue: 175.0 / 255.0)
        case .powderBlue: Color(red: 0.78, green: 0.89, blue: 0.96)
        case .skyBlue: Color(red: 0.66, green: 0.85, blue: 0.94)
        case .lavender: Color(red: 0.88, green: 0.80, blue: 0.94)
        case .white: .white
        case .darkGray: Color(red: 0.16, green: 0.16, blue: 0.17)
        case .black: .black
        }
    }

    var usesLightText: Bool {
        self == .darkGray || self == .black
    }
}

struct ContentView: View {
    @EnvironmentObject var vm: ChatViewModel
    @ObservedObject private var modelCatalog = ModelCatalogStore.shared
    @State private var input = ""
    @State private var showSettings = false
    @AppStorage("chat_font_size") private var fontSize: Double = 15
    @AppStorage("input_height") private var inputHeight: Double = 60
    @AppStorage("background_theme") private var backgroundThemeRaw = BackgroundTheme.sunshine.rawValue
    @AppStorage("custom_models") private var customModelsRaw = ""
    @FocusState private var inputFocused: Bool

    private var customModels: [LLMModel] {
        CustomModels.parse(customModelsRaw, excluding: modelCatalog.catalog.models)
    }

    private var backgroundTheme: BackgroundTheme {
        BackgroundTheme(rawValue: backgroundThemeRaw) ?? .sunshine
    }

    private var foregroundColor: Color {
        backgroundTheme.usesLightText ? .white : .black
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat area
            GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { msg in
                            MessageBubble(
                                role: msg.role,
                                content: msg.content,
                                foregroundColor: foregroundColor,
                                containerWidth: geo.size.width,
                                failure: msg.failure,
                                onRetry: msg.failure != nil && msg.id == vm.messages.last?.id && !vm.isLoading ? { vm.retry(msg.id) } : nil
                            )
                                .id(msg.id)
                        }
                        if !vm.streamingContent.isEmpty {
                            MessageBubble(role: "assistant", content: vm.streamingContent, foregroundColor: foregroundColor, containerWidth: geo.size.width)
                                .id("streaming")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                    .font(.system(size: fontSize, design: .monospaced))
                }
                .onChange(of: vm.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: vm.streamingContent) { _, _ in
                    scrollToBottom(proxy)
                }
            }
            }

            // Drag handle
            foregroundColor.opacity(0.25)
                .frame(height: 1)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            inputHeight = max(40, min(300, inputHeight - value.translation.height))
                        }
                )

            // Input area
            HStack(alignment: .top, spacing: 8) {
                ChatInputField(text: $input, fontSize: fontSize, foregroundColor: foregroundColor, onSubmit: sendMessage)
                    .focused($inputFocused)

                if vm.isLoading {
                    Button(action: vm.stop) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(".", modifiers: .command)
                }
            }
            .frame(height: inputHeight)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        .background(backgroundTheme.color)
        .frame(minWidth: 300, minHeight: 300)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { vm.reset() }) {
                    Text("New chat")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(vm.messages.isEmpty && vm.streamingContent.isEmpty)

                Menu {
                    ForEach(modelCatalog.catalog.models) { model in
                        Button(model.label) { vm.selectedModel = model }
                    }
                    if !customModels.isEmpty {
                        Section("Custom Models") {
                            ForEach(customModels) { model in
                                Button(model.label) { vm.selectedModel = model }
                            }
                        }
                    }
                } label: {
                    Text(vm.selectedModel.label)
                }

                Button(action: { showSettings.toggle() }) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .onAppear {
            inputFocused = true
            vm.reconcileModels(modelCatalog.catalog, customModels: customModels)
        }
        .task { await modelCatalog.refreshIfNeeded() }
        .onChange(of: modelCatalog.catalog) { _, _ in
            vm.reconcileModels(modelCatalog.catalog, customModels: customModels)
        }
        .onChange(of: customModelsRaw) { _, _ in
            vm.reconcileModels(modelCatalog.catalog, customModels: customModels)
        }
        .background {
            // Hidden buttons to capture Cmd+= and Cmd+-
            Button("") { fontSize = min(fontSize + 2, 32) }
                .keyboardShortcut("+", modifiers: .command)
                .hidden()
            Button("") { fontSize = min(fontSize + 2, 32) }
                .keyboardShortcut("=", modifiers: .command)
                .hidden()
            Button("") { fontSize = max(fontSize - 2, 10) }
                .keyboardShortcut("-", modifiers: .command)
                .hidden()
            Button("") { fontSize = 15 }
                .keyboardShortcut("0", modifiers: .command)
                .hidden()
            Button("") { showSettings = true }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func sendMessage() {
        guard !vm.isLoading else { return }
        let text = input
        input = ""
        vm.send(text)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("bottom", anchor: .bottom)
    }
}

struct MessageBubble: View {
    let role: String
    let content: String
    let foregroundColor: Color
    var containerWidth: CGFloat = 600
    var failure: String? = nil
    var onRetry: (() -> Void)? = nil

    private var isNarrow: Bool { containerWidth < 500 }

    var body: some View {
        HStack {
            if role == "user" { Spacer(minLength: isNarrow ? 0 : 60) }

            VStack(alignment: .leading, spacing: 8) {
                if failure != nil && !content.isEmpty {
                    Label("Response interrupted", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(foregroundColor.opacity(0.75))
                }
                ForEach(Array(parseBlocks(content).enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .text(let str):
                        Text(markdownAttributed(str))
                            .textSelection(.enabled)
                            .foregroundStyle(foregroundColor)
                            .tint(foregroundColor)
                    case .code(let str):
                        Text(str)
                            .textSelection(.enabled)
                            .foregroundStyle(foregroundColor)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(foregroundColor.opacity(0.10))
                            .cornerRadius(6)
                    }
                }
                if let failure {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(failure).textSelection(.enabled)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                        if let onRetry {
                            Button("Retry", action: onRetry)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .foregroundStyle(foregroundColor)
                    .padding(10)
                    .background(foregroundColor.opacity(0.08))
                    .cornerRadius(6)
                }
            }
            .padding(10)
            .background(foregroundColor.opacity(role == "user" ? 0.18 : 0.0))
            .cornerRadius(10)

            if role == "assistant" && !isNarrow { Spacer(minLength: 60) }
        }
    }

    private func markdownAttributed(_ str: String) -> AttributedString {
        var result = (try? AttributedString(markdown: str, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(str)
        for run in result.runs {
            if run.link != nil {
                result[run.range].underlineStyle = .single
            }
        }
        return result
    }

    private enum ContentBlock {
        case text(String)
        case code(String)
    }

    private func parseBlocks(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let parts = text.components(separatedBy: "```")
        for (i, part) in parts.enumerated() {
            if i % 2 == 0 {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(.text(trimmed))
                }
            } else {
                // Strip optional language identifier from first line
                var code = part
                if let firstNewline = code.firstIndex(of: "\n") {
                    let firstLine = code[code.startIndex..<firstNewline]
                    if firstLine.allSatisfy({ $0.isLetter || $0.isNumber }) {
                        code = String(code[firstNewline...]).trimmingCharacters(in: .newlines)
                    }
                }
                let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(.code(trimmed))
                }
            }
        }
        return blocks
    }
}
