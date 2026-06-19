import AppKit

final class DocumentSaveCoordinator: NSObject {
    private var completions: [ObjectIdentifier: (Bool) -> Void] = [:]

    func save(_ document: NSDocument, completion: @escaping (Bool) -> Void) {
        let identifier = ObjectIdentifier(document)
        completions[identifier] = completion
        document.save(
            withDelegate: self,
            didSave: #selector(document(_:didSave:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func document(
        _ document: NSDocument,
        didSave: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        let identifier = ObjectIdentifier(document)
        let completion = completions.removeValue(forKey: identifier)
        completion?(didSave)
    }
}
