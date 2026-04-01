import Foundation

enum ColorHex {
    static func normalize(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.hasPrefix("#") {
            value = "#" + value
        }

        let body = value.dropFirst()
        guard body.count == 6,
              body.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }

        return "#" + body.lowercased()
    }
}
