import AppKit

setbuf(stdout, nil)

if CommandLine.arguments.contains("--selftest") {
    exit(runSelfTest(arguments: CommandLine.arguments))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
