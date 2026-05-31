import SwiftUI
import AppKit

struct SpellCheckedTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var focusRequest: Bool
    var placeholder: String = ""
    var maxLines: Int = 5
    var onSubmit: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = WrappingTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        field.font = .preferredFont(forTextStyle: .body)
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.cell?.truncatesLastVisibleLine = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = maxLines
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.required, for: .vertical)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        nsView.maximumNumberOfLines = maxLines
        if focusRequest {
            DispatchQueue.main.async {
                if let window = nsView.window {
                    window.makeFirstResponder(nsView)
                }
                if let editor = nsView.currentEditor() {
                    let end = nsView.stringValue.count
                    editor.selectedRange = NSRange(location: end, length: 0)
                }
                focusRequest = false
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SpellCheckedTextField

        init(_ parent: SpellCheckedTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let modifiers = NSApp.currentEvent?.modifierFlags ?? []
                if modifiers.contains(.shift) || modifiers.contains(.option) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

private final class WrappingTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            editor.isContinuousSpellCheckingEnabled = true
            editor.isAutomaticSpellingCorrectionEnabled = true
            editor.isAutomaticTextReplacementEnabled = true
            editor.isAutomaticQuoteSubstitutionEnabled = true
            editor.isAutomaticDashSubstitutionEnabled = true
            editor.isAutomaticDataDetectionEnabled = true
            editor.isGrammarCheckingEnabled = true
            editor.smartInsertDeleteEnabled = true
        }
        return result
    }
}
