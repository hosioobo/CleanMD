import Combine
import Darwin
import Foundation

final class ReloadConflictMonitor: ObservableObject {
    @Published private(set) var state: ExternalFileState = .idle
    @Published private(set) var pendingDiskText: String?

    private var fileURL: URL?
    private var baselineText = ""
    private var currentText = ""
    private var isKeepingCurrentVersion = false
    private var source: DispatchSourceFileSystemObject?

    func start(fileURL: URL?, currentText: String) {
        stop()
        self.fileURL = fileURL
        self.baselineText = currentText
        self.currentText = currentText
        isKeepingCurrentVersion = false
        state = .idle
        pendingDiskText = nil

        guard let fileURL else { return }
        evaluateConflict()
        installSource(for: fileURL)
    }

    func updateCurrentText(_ text: String) {
        currentText = text
        if state != .idle {
            evaluateConflict()
        }
    }

    func markResolved(currentText: String) {
        markSynchronized(currentText: currentText)
    }

    func markSaved(currentText: String) {
        markSynchronized(currentText: currentText)
    }

    func keepCurrentVersion() {
        isKeepingCurrentVersion = true
        state = .conflict
        restartSource()
    }

    func dismissFileUnavailable() {
        guard state == .fileUnavailable else { return }
        state = .idle
    }

    func stop() {
        source?.cancel()
        source = nil
        fileURL = nil
        baselineText = ""
        currentText = ""
        isKeepingCurrentVersion = false
        state = .idle
        pendingDiskText = nil
    }

    private func installSource(for fileURL: URL) {
        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let nextSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: .main
        )

        nextSource.setEventHandler { [weak self, weak nextSource] in
            guard let self else { return }
            let event = nextSource?.data ?? []
            self.evaluateConflict()

            if event.contains(.delete) || event.contains(.rename) {
                self.restartSource()
            }
        }
        nextSource.setCancelHandler {
            close(descriptor)
        }
        nextSource.resume()
        source = nextSource
    }

    private func restartSource() {
        guard let fileURL else { return }
        source?.cancel()
        source = nil
        installSource(for: fileURL)
    }

    private func markSynchronized(currentText: String) {
        self.currentText = currentText
        baselineText = currentText
        isKeepingCurrentVersion = false
        state = .idle
        pendingDiskText = nil
        restartSource()
    }

    private func evaluateConflict() {
        do {
            guard let diskText = try DocumentReloading.loadText(from: fileURL) else {
                state = .fileUnavailable
                pendingDiskText = nil
                return
            }

            if isKeepingCurrentVersion {
                if diskText == currentText {
                    baselineText = diskText
                    isKeepingCurrentVersion = false
                    state = .idle
                    pendingDiskText = nil
                } else {
                    state = .conflict
                    pendingDiskText = diskText
                }
                return
            }

            let nextState = DocumentReloading.externalFileState(
                baselineText: baselineText,
                currentText: currentText,
                diskText: diskText
            )

            state = nextState
            if nextState == .idle {
                pendingDiskText = nil
                if diskText == currentText {
                    baselineText = diskText
                }
            } else {
                pendingDiskText = diskText
            }
        } catch {
            state = .fileUnavailable
            pendingDiskText = nil
        }
    }

    deinit {
        source?.cancel()
    }
}
