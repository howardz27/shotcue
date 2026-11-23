import AppKit

let application = NSApplication.shared

if (3...4).contains(CommandLine.arguments.count), CommandLine.arguments[1] == "--make-icon" {
    let directory = URL(fileURLWithPath: CommandLine.arguments[2])
    let source = CommandLine.arguments.count == 4 ? URL(fileURLWithPath: CommandLine.arguments[3]) : nil
    do { try DevelopmentArtifacts.icon(at: directory, source: source); exit(EXIT_SUCCESS) }
    catch { fputs("\(error)\n", stderr); exit(EXIT_FAILURE) }
}
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--self-test" {
    do { try DevelopmentArtifacts.verify(at: URL(fileURLWithPath: CommandLine.arguments[2])); exit(EXIT_SUCCESS) }
    catch { fputs("\(error)\n", stderr); exit(EXIT_FAILURE) }
}

let delegate = AppActions()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
