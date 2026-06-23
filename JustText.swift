import SwiftUI
import Darwin

@main
struct TextPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    init() { Doc.shared.text = TextPadApp.readStdin() }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
    static func readStdin() -> String {
        guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else { return "" }
        return String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // The window isn't created until after launch; bring it to the front next tick.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) {
        guard isatty(FileHandle.standardOutput.fileDescriptor) == 0 else { return }
        FileHandle.standardOutput.write(Data(Doc.shared.text.utf8))
    }
}

final class Doc: ObservableObject {
    static let shared = Doc()
    @Published var text = ""
}

struct ContentView: View {
    @ObservedObject private var doc = Doc.shared
    @State private var command = ""
    @State private var prompting = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        TextEditor(text: $doc.text)
            .font(.system(.body, design: .monospaced))
            .background {
                Button("") { prompting = true }
                    .keyboardShortcut("|", modifiers: [.command, .shift])
                    .hidden()
            }
            .alert("Pipe through command", isPresented: $prompting) {
                TextField("shell command", text: $command)
                Button("Run", action: run)
                Button("Cancel", role: .cancel) {}
            }
    }

    func setText(_ new: String) {
        let previous = doc.text
        undoManager?.registerUndo(withTarget: doc) { [self] _ in setText(previous) }
        undoManager?.setActionName("Pipe")
        doc.text = new
    }

    func run() {
        guard !command.isEmpty else { return }
        let cmd = command, input = doc.text
        DispatchQueue.global().async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", cmd]
            let inPipe = Pipe(), outPipe = Pipe()
            p.standardInput = inPipe
            p.standardOutput = outPipe
            p.standardError = outPipe
            let result: String
            do {
                try p.run()
                DispatchQueue.global().async {
                    inPipe.fileHandleForWriting.write(Data(input.utf8))
                    try? inPipe.fileHandleForWriting.close()
                }
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                result = String(decoding: data, as: UTF8.self)
            } catch {
                result = "Error: \(error.localizedDescription)"
            }
            DispatchQueue.main.async { setText(result) }
        }
    }
}
