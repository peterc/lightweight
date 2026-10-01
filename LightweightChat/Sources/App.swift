import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI supplies a View menu even when an app has no useful view commands.
        // Defer until its command menus have been installed, then remove it.
        DispatchQueue.main.async {
            guard let mainMenu = NSApp.mainMenu,
                  let viewMenuItem = mainMenu.items.first(where: { $0.submenu?.title == "View" })
            else { return }

            mainMenu.removeItem(viewMenuItem)
        }
    }
}

@main
struct LightweightChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("background_theme") private var backgroundThemeRaw = BackgroundTheme.sunshine.rawValue

    private var colorScheme: ColorScheme {
        let theme = BackgroundTheme(rawValue: backgroundThemeRaw) ?? .sunshine
        return theme.usesLightText ? .dark : .light
    }

    var body: some Scene {
        WindowGroup {
            ChatWindowView()
                .preferredColorScheme(colorScheme)
                .background(WindowAccessor())
        }
        .defaultSize(width: 800, height: 700)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Lightweight") {
                    AboutPanel.show()
                }
            }
        }
    }
}

private struct ChatWindowView: View {
    // Each WindowGroup window owns its conversation and active request.
    @StateObject private var chatVM = ChatViewModel()

    var body: some View {
        ContentView()
            .environmentObject(chatVM)
    }
}

private enum AboutPanel {
    @MainActor
    static func show() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let credits = NSMutableAttributedString(
            string: "Created by Peter Cooper\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .paragraphStyle: style,
            ]
        )
        credits.append(NSAttributedString(
            string: "github.com/peterc/lightweight",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.linkColor,
                .link: URL(string: "https://github.com/peterc/lightweight")!,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .paragraphStyle: style,
            ]
        ))
        credits.append(NSAttributedString(
            string: "\n\nUses ",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .paragraphStyle: style,
            ]
        ))
        credits.append(NSAttributedString(
            string: "OpenRouter",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.linkColor,
                .link: URL(string: "https://openrouter.ai")!,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .paragraphStyle: style,
            ]
        ))
        credits.append(NSAttributedString(
            string: ".\nOpenRouter is a trademark of OpenRouter, Inc.\nLightweight is not affiliated with or endorsed by OpenRouter.",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .paragraphStyle: style,
            ]
        ))

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}
