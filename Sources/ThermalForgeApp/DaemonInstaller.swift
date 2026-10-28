//
//  DaemonInstaller.swift
//  ThermalForge
//
//  Installs (or re-syncs) the privileged background daemon using the CLI that
//  ships inside the app bundle, so setting ThermalForge up needs no Terminal —
//  just the standard macOS administrator prompt.
//

import AppKit
import Foundation
import ThermalForgeCore

enum DaemonInstallResult {
    case installed
    case cancelled
    case failed(String)
}

enum DaemonInstaller {
    /// The CLI copied into Contents/Resources by the build (see `thermalforge
    /// build-app --cli`). Its `install` verb is what the Terminal path runs; here
    /// it is invoked from inside the app so the user never types a command.
    static var bundledCLI: URL? {
        Bundle.main.url(forResource: "thermalforge", withExtension: nil)
    }

    /// True when a daemon has been installed on this Mac before: the launchd
    /// plist is the durable marker (the socket only exists while it runs).
    static var isDaemonInstalled: Bool {
        FileManager.default.fileExists(atPath: ThermalForgeDaemon.plistPath)
    }

    /// Single-quote a value for /bin/sh.
    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escape a value for an AppleScript double-quoted string literal.
    private static func appleScriptQuote(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Run `<bundled cli> install` as root behind the system auth prompt.
    /// Blocking — call it off the main thread.
    static func install() -> DaemonInstallResult {
        guard let cli = bundledCLI else {
            return .failed("This copy of ThermalForge is missing its installer. Reinstall the app.")
        }

        // The installer bakes SUDO_UID into the launchd plist so the control
        // socket belongs to the logged-in user; inside the app we supply the
        // same value directly.
        let command = "SUDO_UID=\(getuid()) \(shellQuote(cli.path)) install"
        let script = "do shell script \(appleScriptQuote(command)) with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            return .failed("Couldn't start the installer: \(error.localizedDescription)")
        }
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let message = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 {
            return .installed
        }
        // do shell script reports a dismissed auth dialog as an -128 execution error.
        if message.contains("-128") || message.lowercased().contains("user canceled") {
            return .cancelled
        }
        return .failed(message.isEmpty
            ? "The installer stopped with status \(process.terminationStatus)."
            : message)
    }

    /// Quit and reopen so launch adopts the freshly installed daemon. The
    /// relauncher is detached first, otherwise terminating the app would kill it.
    static func relaunch() {
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = ["-c", "sleep 1.5; /usr/bin/open \(shellQuote(Bundle.main.bundlePath))"]
        relauncher.standardOutput = FileHandle.nullDevice
        relauncher.standardError = FileHandle.nullDevice
        do {
            try relauncher.run()
        } catch {
            TFLogger.shared.error("Relaunch after setup failed to start: \(error)")
            return
        }
        NSApp.terminate(nil)
    }
}
