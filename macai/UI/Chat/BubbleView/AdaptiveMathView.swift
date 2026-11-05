//
//  MathView.swift
//  macai
//
//  Created by Renat on 24.06.2024.
//

import SwiftUI
import SwiftMath

struct MathViewSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MathView: NSViewRepresentable {
    var equation: String
    var fontSize: CGFloat
    
    func makeNSView(context: Context) -> MTMathUILabel {
        let view = makeMathLabel(fontSize: fontSize, textColor: .textColor)
        view.textAlignment = .left
        return view
    }
    
    func updateNSView(_ view: MTMathUILabel, context: Context) {
        view.latex = escapingPercent(equation)
        view.fontSize = fontSize
        view.setNeedsDisplay(view.bounds)
    }
}

struct AdaptiveMathView: View {
    let equation: String
    let fontSize: CGFloat
    @State private var size: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            MathView(equation: equation, fontSize: fontSize)
                .background(GeometryReader { innerGeometry in
                    Color.clear.preference(key: MathViewSizePreferenceKey.self, value: innerGeometry.size)
                })
                .onPreferenceChange(MathViewSizePreferenceKey.self) { newSize in
                    DispatchQueue.main.async {
                        self.size = newSize
                    }
                }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// SwiftMath silently drops a bare `%`; LLMs use it as a percent sign, not a comment
private func escapingPercent(_ latex: String) -> String {
    latex.replacingOccurrences(of: "(?<!\\\\)%", with: "\\\\%", options: .regularExpression)
}

private func makeMathLabel(fontSize: CGFloat, textColor: NSColor) -> MTMathUILabel {
    let label = MTMathUILabel()
    label.font = MTFontManager().termesFont(withSize: fontSize)
    label.textColor = textColor
    label.labelMode = .text
    return label
}

/// Inline formulas rendered as image attachments inside text
enum InlineMath {
    /// U+FFFC is the character an NSTextAttachment occupies in an attributed string
    static let attachmentCharacter = "\u{FFFC}"

    /// Inline code spans (matched only to be skipped), `\(...\)`, and `$...$` with Pandoc rules,
    /// so "$5 and $10" stays text
    private static let regex = try! NSRegularExpression(
        pattern: #"`[^`]*`|\\\((.+?)\\\)|(?<![\\$])\$(?![\s$])(.+?)(?<![\s\\])\$(?![\d$])"#
    )

    /// Messages are re-rendered on every search step and when streaming ends, so typeset formulas are reused
    private static let cache = NSCache<NSString, NSTextAttachment>()

    /// Ranges of whole inline formulas (delimiters included) and their LaTeX
    static func formulas(in text: String) -> [(range: NSRange, latex: String)] {
        guard text.contains("$") || text.contains("\\(") else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            let latexRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            guard latexRange.location != NSNotFound else { return nil }
            return (match.range, nsText.substring(with: latexRange))
        }
    }

    /// Replaces each inline formula with an attachment character and returns the attachments in order.
    /// Formulas SwiftMath can't parse stay as text.
    static func extract(from text: String, fontSize: CGFloat, textColor: NSColor) -> (String, [NSTextAttachment]) {
        let nsText = text as NSString
        var result = ""
        var attachments: [NSTextAttachment] = []
        var location = 0
        for formula in formulas(in: text) {
            guard let attachment = attachment(latex: formula.latex, fontSize: fontSize, textColor: textColor) else { continue }
            result += nsText.substring(with: NSRange(location: location, length: formula.range.location - location))
            result += attachmentCharacter
            attachments.append(attachment)
            location = NSMaxRange(formula.range)
        }
        result += nsText.substring(from: location)
        return (result, attachments)
    }

    /// Puts the attachments from `extract` back on their attachment characters
    static func attach(_ attachments: [NSTextAttachment], to attributedString: NSMutableAttributedString) {
        let string = attributedString.string as NSString
        var searchStart = 0
        for attachment in attachments {
            let range = string.range(of: attachmentCharacter, range: NSRange(location: searchStart, length: string.length - searchStart))
            guard range.location != NSNotFound else { return }
            attributedString.addAttribute(.attachment, value: attachment, range: range)
            searchStart = NSMaxRange(range)
        }
    }

    private static func attachment(latex: String, fontSize: CGFloat, textColor: NSColor) -> NSTextAttachment? {
        let cacheKey = "\(latex):\(fontSize):\(textColor)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let label = makeMathLabel(fontSize: fontSize, textColor: textColor)
        label.latex = escapingPercent(latex)
        guard label.error == nil else { return nil }

        // The label puts the baseline `descent` above its bottom only when it is at least half the font size tall
        let size = label.fittingSize
        label.frame.size = CGSize(width: size.width, height: max(size.height, fontSize / 2))
        label.layout()
        guard let displayList = label.displayList else { return nil }

        let attachment = NSTextAttachment()
        attachment.image = NSImage(size: label.frame.size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            displayList.draw(context)
            return true
        }
        attachment.bounds = CGRect(x: 0, y: -displayList.descent, width: label.frame.width, height: label.frame.height)
        cache.setObject(attachment, forKey: cacheKey)
        return attachment
    }
}
