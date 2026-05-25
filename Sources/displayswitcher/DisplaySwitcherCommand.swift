import ArgumentParser
import CLIKit
import DDCKit

/// The `displayswitcher` command — a single, fully explicit flag-based CLI.
///
/// Every action is a self-describing flag (`--get-brightness`,
/// `--set-contrast`, …) and the target display is always stated with
/// `--on-display`. Exactly one action runs per invocation.
struct DisplaySwitcherCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "displayswitcher",
        abstract: "Control external monitor settings (brightness, contrast, input) over DDC/CI.",
        usage: """
            displayswitcher --list
            displayswitcher --get-brightness --on-display <n>
            displayswitcher --set-brightness <0-100> --on-display <n>
            """,
        discussion: """
            Choose exactly one action. Every action except --list requires \
            --on-display.

            EXAMPLES:
              displayswitcher --list
              displayswitcher --get-brightness --on-display 2
              displayswitcher --set-brightness 60 --on-display 2
              displayswitcher --set-contrast 50 --on-display 1
              displayswitcher --set-input hdmi1 --on-display 3
              displayswitcher --set-brightness 25 --on-display all
              displayswitcher --upgrade

            Looking for sponsors — https://github.com/sponsors/lintuxt
            """,
        version: "\(BuildInfo.version) (build \(BuildInfo.build))"
    )

    // MARK: Actions (choose exactly one)

    @Flag(help: "Show every display and its current settings (the default with no flag).")
    var list = false

    @Flag(help: "Read the brightness of --on-display.")
    var getBrightness = false

    @Option(help: ArgumentHelp("Set brightness on --on-display.", valueName: "0-100"))
    var setBrightness: Int?

    @Flag(help: "Read the contrast of --on-display.")
    var getContrast = false

    @Option(help: ArgumentHelp("Set contrast on --on-display.", valueName: "0-100"))
    var setContrast: Int?

    @Flag(help: "Read the input source of --on-display.")
    var getInput = false

    @Option(help: ArgumentHelp("Set the input source on --on-display.", valueName: "hdmi1|dp1|usbc|…"))
    var setInput: String?

    @Flag(help: "Check for a newer release and install it.")
    var upgrade = false

    // MARK: Target

    @Option(help: ArgumentHelp("Which display to act on — a # from --list, or 'all'. "
                               + "Required for every action except --list.",
                               valueName: "n|all"))
    var onDisplay: DisplaySelector?

    func run() throws {
        let actions = try chosenActions()
        guard actions.count == 1 else {
            // Bare `displayswitcher` shows the display list — same as `--list`.
            if actions.isEmpty { try runList(); return }
            throw ValidationError(
                "Choose exactly one action (e.g. --get-brightness or --set-contrast).")
        }

        switch actions[0] {
        case .list:
            try runList()
        case .upgrade:
            try Upgrade.runSync(
                repo: "lintuxt/displayswitcher",
                currentVersion: BuildInfo.version,
                installerURL: "https://raw.githubusercontent.com/lintuxt/displayswitcher/main/install.sh")
        case .get(let code):
            try runControl(code, on: try requireDisplay(), value: nil)
        case .set(let code, let value):
            try runControl(code, on: try requireDisplay(), value: value)
        }
    }

    /// One concrete thing the CLI can do.
    private enum Action {
        case list
        case upgrade
        case get(VCPCode)
        case set(VCPCode, UInt16)
    }

    /// Collects the actions the flags asked for, validating their values.
    private func chosenActions() throws -> [Action] {
        var actions: [Action] = []
        if list { actions.append(.list) }
        if upgrade { actions.append(.upgrade) }
        if getBrightness { actions.append(.get(.brightness)) }
        if getContrast { actions.append(.get(.contrast)) }
        if getInput { actions.append(.get(.inputSource)) }
        if let value = setBrightness {
            actions.append(.set(.brightness, try percent(value, "brightness")))
        }
        if let value = setContrast {
            actions.append(.set(.contrast, try percent(value, "contrast")))
        }
        if let value = setInput {
            actions.append(.set(.inputSource, try inputCode(value)))
        }
        return actions
    }

    /// The explicit display target, or a clear error when it's missing.
    private func requireDisplay() throws -> DisplaySelector {
        guard let onDisplay else {
            throw ValidationError(
                "This action needs a target — add --on-display <n> "
                + "(a # from --list, or 'all').")
        }
        return onDisplay
    }

    /// Validates a 0–100 setting value.
    private func percent(_ value: Int, _ name: String) throws -> UInt16 {
        guard (0...100).contains(value) else {
            throw ValidationError("\(name) must be between 0 and 100 (got \(value)).")
        }
        return UInt16(value)
    }

    /// Parses an input-source name (or raw number) into a VCP value.
    private func inputCode(_ source: String) throws -> UInt16 {
        if let input = InputSource(name: source) {
            return UInt16(input.rawValue)
        }
        if let number = UInt16(source) {
            return number
        }
        throw ValidationError(
            "Unknown input '\(source)'. Try: hdmi1, hdmi2, dp1, dp2, usbc, vga, dvi.")
    }
}
