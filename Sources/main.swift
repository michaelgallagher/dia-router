// DiaRouter: a stand-in default browser that opens each link in the right Dia profile.
//
// macOS hands every http/https link to this app. It matches the link against
// ~/.config/dia-router/rules.json and asks Dia (via AppleScript) to open it in a
// new tab in the chosen profile. If anything goes wrong, the link is opened in
// Dia the ordinary way, so a link is never lost.

import AppKit

let diaBundleID = "company.thebrowser.dia"
let rulesURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/dia-router/rules.json")
let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/DiaRouter.log")

// MARK: - Logging

func log(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: logURL)
    }
}

// MARK: - Rules

struct Rule: Decodable {
    let profile: String
    let match: [String]
}

struct RuleSet: Decodable {
    /// Profile for links no rule matches. Omit it to use whichever profile is active in Dia.
    let `default`: String?
    let rules: [Rule]
}

/// Read fresh on every link, so edits to the rules file apply immediately.
func loadRules() -> RuleSet {
    do {
        let data = try Data(contentsOf: rulesURL)
        return try JSONDecoder().decode(RuleSet.self, from: data)
    } catch {
        log("Could not read \(rulesURL.path): \(error)")
        return RuleSet(default: nil, rules: [])
    }
}

/// A pattern is a domain, optionally followed by a path prefix.
/// "example.com" matches example.com and all its subdomains ("*.example.com" means the same).
/// "github.com/nhsuk" matches github.com URLs whose path starts with /nhsuk.
func pattern(_ pattern: String, matches url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    var pattern = pattern.lowercased()
    if pattern.hasPrefix("*.") { pattern.removeFirst(2) }

    let parts = pattern.split(separator: "/", maxSplits: 1)
    guard let domain = parts.first.map(String.init) else { return false }
    guard host == domain || host.hasSuffix("." + domain) else { return false }

    if parts.count > 1 {
        return url.path.lowercased().hasPrefix("/" + parts[1])
    }
    return true
}

func profile(for url: URL, in ruleSet: RuleSet) -> String? {
    for rule in ruleSet.rules where rule.match.contains(where: { pattern($0, matches: url) }) {
        return rule.profile
    }
    return ruleSet.default
}

// MARK: - Talking to Dia

func appleScriptString(_ value: String) -> String {
    let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

@discardableResult
func runAppleScript(_ source: String) throws -> NSAppleEventDescriptor {
    var error: NSDictionary?
    guard let script = NSAppleScript(source: source) else {
        throw NSError(domain: "DiaRouter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not compile script"])
    }
    let result = script.executeAndReturnError(&error)
    if let error {
        let message = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
        let number = error[NSAppleScript.errorNumber] as? Int ?? 0
        throw NSError(domain: "DiaRouter", code: number, userInfo: [NSLocalizedDescriptionKey: message])
    }
    return result
}

/// Dia's profiles are reached through a window, so make sure one exists.
func ensureDiaWindow() throws {
    let count = try runAppleScript(#"tell application "Dia" to count windows"#).int32Value
    if count > 0 { return }

    // Reopening an app with no windows normally makes it open one.
    try runAppleScript(#"tell application "Dia" to reopen"#)
    for _ in 0..<30 {
        Thread.sleep(forTimeInterval: 0.1)
        if try runAppleScript(#"tell application "Dia" to count windows"#).int32Value > 0 { return }
    }
    throw NSError(domain: "DiaRouter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Dia has no window open"])
}

func openInDia(_ url: URL, profile: String?) throws {
    try ensureDiaWindow()

    let target = profile.map { "first profile of window 1 whose name is \(appleScriptString($0))" }
        ?? "active profile of window 1"

    try runAppleScript("""
        tell application "Dia"
            set p to \(target)
            set t to make new tab at end of tabs of p
            set URL of t to \(appleScriptString(url.absoluteString))
            focus t
            activate
        end tell
        """)
}

/// Fallback: hand the link straight to Dia, which opens it in its current profile.
func openPlainlyInDia(_ url: URL) {
    guard let dia = NSWorkspace.shared.urlForApplication(withBundleIdentifier: diaBundleID) else {
        log("Dia is not installed; cannot open \(url)")
        return
    }
    NSWorkspace.shared.open([url], withApplicationAt: dia, configuration: NSWorkspace.OpenConfiguration())
}

func route(_ url: URL) {
    let target = profile(for: url, in: loadRules())
    do {
        try openInDia(url, profile: target)
        log("\(url.absoluteString) -> \(target ?? "active profile")")
    } catch {
        log("\(url.absoluteString) -> \(target ?? "active profile") FAILED (\(error.localizedDescription)); opened in Dia without routing")
        openPlainlyInDia(url)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        route(url)
    }

    /// Local .html files and other documents opened with the default browser.
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(route)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
