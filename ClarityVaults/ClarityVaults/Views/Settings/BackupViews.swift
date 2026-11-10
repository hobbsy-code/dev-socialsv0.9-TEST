import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings section: back up to iCloud Drive / Files, restore, undo a restore.
struct BackupSection: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context

    @State private var document: BackupDocument?
    @State private var filename = "Clarity Vaults backup"
    @State private var showingExporter = false
    @State private var showingRestore = false
    @State private var confirmUndo = false
    @State private var message: String?
    @State private var undoAvailable = BackupService.safetyCopy != nil

    var body: some View {
        Section {
            Button {
                startBackup()
            } label: {
                Label("Back up now", systemImage: "icloud.and.arrow.up")
            }
            Button {
                showingRestore = true
            } label: {
                Label("Restore from backup", systemImage: "icloud.and.arrow.down")
            }
            if undoAvailable {
                Button {
                    confirmUndo = true
                } label: {
                    Label("Undo last restore", systemImage: "arrow.uturn.backward")
                }
            }
        } header: {
            Text("Backup")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let last = settings.lastBackupAt {
                    Text("Last backed up \(Fmt.dayWithWeekday(last)) \(last.formatted(date: .omitted, time: .shortened)).")
                } else {
                    Text("Not backed up yet.")
                }
                Text("Choose iCloud Drive when saving, and your backup is kept safely in your own iCloud. It isn't sent to us. Back up monthly, and before changing phones. Backup files aren't password-protected, so keep them in your own iCloud Drive.")
            }
        }
        .fileExporter(isPresented: $showingExporter, document: document, contentType: .json, defaultFilename: filename) { result in
            switch result {
            case .success:
                settings.lastBackupAt = .now
                message = "Backup saved. To restore later, use Restore from backup and pick this file."
            case .failure(let error):
                message = "The backup couldn't be saved: \(error.localizedDescription)"
            }
            document = nil
        }
        .restoreFlow(isPresented: $showingRestore) { undoAvailable = BackupService.safetyCopy != nil }
        .confirmationDialog("Undo the last restore?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Put my previous data back", role: .destructive) {
                do {
                    try BackupService.undoLastRestore(context: context, settings: settings)
                    message = "Your data is back as it was before the restore."
                } catch {
                    message = "Undo didn't work: \(error.localizedDescription)"
                }
                undoAvailable = BackupService.safetyCopy != nil
            }
        } message: {
            Text("This replaces what's in the app now with the data you had just before your last restore.")
        }
        .alert("Backup", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func startBackup() {
        do {
            let backup = try BackupService.makeBackup(context: context, settings: settings)
            document = try BackupDocument(backup: backup)
            filename = backup.suggestedFilename
            showingExporter = true
        } catch {
            message = "The backup couldn't be created: \(error.localizedDescription)"
        }
    }
}

// MARK: - Restore flow (used in Settings and onboarding)

private struct RestoreFlow: ViewModifier {
    @Binding var isPresented: Bool
    var onRestored: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context
    @State private var pending: BackupFile?
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do { pending = try BackupService.readBackup(at: url) }
                    catch { errorMessage = error.localizedDescription }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .confirmationDialog(pending.map { "Restore backup from \(Fmt.dayWithWeekday($0.createdAt))?" } ?? "",
                                isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible, presenting: pending) { backup in
                Button("Replace my data with this backup", role: .destructive) {
                    do {
                        try BackupService.restore(backup, context: context, settings: settings)
                        onRestored()
                    } catch {
                        errorMessage = "The restore didn't finish: \(error.localizedDescription)"
                    }
                    pending = nil
                }
                Button("Cancel", role: .cancel) { pending = nil }
            } message: { backup in
                Text("Contains \(backup.summary). Everything currently in the app will be replaced. A copy of your current data is kept, so you can undo this in Settings.")
            }
            .alert("Couldn't restore", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }
}

extension View {
    /// Lets the user pick a backup file (e.g. from iCloud Drive), confirm, and restore it.
    func restoreFlow(isPresented: Binding<Bool>, onRestored: @escaping () -> Void = {}) -> some View {
        modifier(RestoreFlow(isPresented: isPresented, onRestored: onRestored))
    }
}
