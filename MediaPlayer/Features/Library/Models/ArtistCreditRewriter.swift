import Foundation

nonisolated enum ArtistCreditRewriter {
    static func replacing(
        _ artist: String,
        in credit: String,
        with replacement: String,
        separatorCharacters: String
    ) -> String? {
        if normalize(credit) == normalize(artist) {
            return replacement
        }

        let separators = SmartArtistGroupingSettings
            .normalizedSeparatorCharacters(separatorCharacters)
        let wordPattern = #"\s+(?:feat(?:uring)?|ft|with)\.?\s+"#
        let pattern = separators.isEmpty
            ? wordPattern
            : "[\(NSRegularExpression.escapedPattern(for: separators))]|\(wordPattern)"
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let matches = expression.matches(
            in: credit,
            range: NSRange(credit.startIndex..<credit.endIndex, in: credit)
        )
        let boundaries = matches.map(\.range)
        var segments: [Range<String.Index>] = []
        var start = credit.startIndex
        for boundary in boundaries {
            guard let range = Range(boundary, in: credit) else { return nil }
            segments.append(start..<range.lowerBound)
            start = range.upperBound
        }
        segments.append(start..<credit.endIndex)

        let normalizedArtist = normalize(artist)
        var result = ""
        var cursor = credit.startIndex
        var didReplace = false
        for segment in segments {
            result.append(contentsOf: credit[cursor..<segment.lowerBound])
            let value = String(credit[segment])
            if normalize(value) == normalizedArtist {
                result.append(contentsOf: value.prefix(while: \.isWhitespace))
                result += replacement
                let trailing = value.reversed().prefix(while: \.isWhitespace)
                result += String(trailing.reversed())
                didReplace = true
            } else {
                result += value
            }
            cursor = segment.upperBound
        }
        result.append(contentsOf: credit[cursor..<credit.endIndex])
        return didReplace ? result : nil
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }
}
