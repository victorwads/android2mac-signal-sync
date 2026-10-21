import AppKit
import SwiftUI

@main
struct PhoneSignalSyncApp: App {
    var body: some Scene {
        MenuBarExtra("Phone Signal Sync", systemImage: "antenna.radiowaves.left.and.right.slash") {
            Text("Phone Signal Sync")
                .font(.headline)

            Text("Nenhum celular conectado")
            Text("Sinal e tráfego ainda não disponíveis")
                .foregroundStyle(.secondary)

            Divider()

            Button("Sair") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
