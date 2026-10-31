import Foundation

// The Hush executable is both the menu bar app and the `hush` command line
// tool (see HushCLI.swift). Decide which before AppKit starts.
if let arguments = HushCLIEntry.cliArguments(from: CommandLine.arguments) {
    let appURL = AppLocation.bundleURL()
    let version = appURL.flatMap { Bundle(url: $0) }?
        .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let context = CLIContext(
        transport: AppTransport(appURL: appURL),
        version: version,
        out: { FileHandle.standardOutput.write(Data(($0 + "\n").utf8)) },
        err: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    )
    exit(HushCLI.run(arguments: arguments, context: context))
}

HushApp.main()
