import Foundation

enum MarkdownLinkDestinationNormalizer {
    static func normalize(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard !lines.isEmpty else { return text }

        var normalized: [String] = []
        var activeFence: Fence?

        for line in lines {
            if let fence = activeFence {
                normalized.append(line)
                if isClosingFence(line, matching: fence) {
                    activeFence = nil
                }
                continue
            }

            if let fence = fencedCodeBlockStart(for: line) {
                activeFence = fence
                normalized.append(line)
                continue
            }

            normalized.append(normalizeLine(line))
        }

        return normalized.joined(separator: "\n")
    }

    private static func normalizeLine(_ line: String) -> String {
        var output = ""
        var index = line.startIndex

        while index < line.endIndex {
            if line[index] == "]",
               let openParenIndex = line.index(index, offsetBy: 1, limitedBy: line.endIndex),
               openParenIndex < line.endIndex,
               line[openParenIndex] == "(",
               let closeParenIndex = line[openParenIndex...].firstIndex(of: ")") {
                output.append(contentsOf: line[index...openParenIndex])

                let destinationStart = line.index(after: openParenIndex)
                let destination = String(line[destinationStart..<closeParenIndex])
                output.append(normalizedDestination(destination))
                output.append(")")

                index = line.index(after: closeParenIndex)
                continue
            }

            output.append(line[index])
            index = line.index(after: index)
        }

        return output
    }

    private static func normalizedDestination(_ destination: String) -> String {
        guard shouldWrapInAngleBrackets(destination) else { return destination }
        return "<\(destination)>"
    }

    private static func shouldWrapInAngleBrackets(_ destination: String) -> Bool {
        guard !destination.isEmpty else { return false }
        guard !destination.hasPrefix("<"), !destination.hasSuffix(">") else { return false }
        guard !destination.hasPrefix("#") else { return false }
        guard destination.contains(where: \.isWhitespace) else { return false }
        guard !destination.contains("\""), !destination.contains("'") else { return false }

        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression) == nil else {
            return false
        }

        return true
    }

    private struct Fence {
        let marker: Character
        let length: Int
    }

    private static func fencedCodeBlockStart(for line: String) -> Fence? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else { return nil }

        let fenceLength = trimmed.prefix { $0 == marker }.count
        guard fenceLength >= 3 else { return nil }
        return Fence(marker: marker, length: fenceLength)
    }

    private static func isClosingFence(_ line: String, matching fence: Fence) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == fence.marker else { return false }

        let fenceLength = trimmed.prefix { $0 == fence.marker }.count
        guard fenceLength >= fence.length else { return false }

        return trimmed.dropFirst(fenceLength).trimmingCharacters(in: .whitespaces).isEmpty
    }
}
