import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SpellCheckedTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var focusRequest: Bool
    var placeholder: String = ""
    var maxLines: Int = 5
    var onSubmit: () -> Void = {}
    var onImageData: (Data) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = WrappingTextField()
        field.onImageData = onImageData
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
        (nsView as? WrappingTextField)?.onImageData = onImageData
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
    var onImageData: ((Data) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        // Reject image/file drops so they fall through to the chat window's drop
        // handler instead of being inserted as a file path. Keep plain-text drops.
        unregisterDraggedTypes()
        registerForDraggedTypes([.string])
        if let editor = currentEditor() as? NSTextView {
            editor.unregisterDraggedTypes()
            editor.registerForDraggedTypes([.string])
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

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            if pasteImagesIfAvailable() { return true }
        }
        return super.performKeyEquivalent(with: event)
    }

    private func pasteImagesIfAvailable() -> Bool {
        guard let onImageData else { return false }
        let pb = NSPasteboard.general
        var found = false

        let opts: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: opts) as? [URL], !urls.isEmpty {
            for url in urls {
                if let data = try? Data(contentsOf: url) {
                    onImageData(data)
                    found = true
                }
            }
            if found { return true }
        }

        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !images.isEmpty {
            for img in images {
                if let data = Self.pngData(from: img) {
                    onImageData(data)
                    found = true
                }
            }
        }
        return found
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
