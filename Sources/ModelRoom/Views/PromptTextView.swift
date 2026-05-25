import AppKit
import SwiftUI

struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var isComposingText: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = FocusReportingTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 15.5)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.focusChanged = { focused in
            DispatchQueue.main.async {
                isFocused = focused
            }
        }
        textView.markedTextChanged = { isComposing in
            DispatchQueue.main.async {
                isComposingText = isComposing
            }
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? FocusReportingTextView else { return }
        if textView.string != text && !textView.hasMarkedText() {
            textView.string = text
        }
        textView.font = .systemFont(ofSize: 15.5)
        DispatchQueue.main.async {
            isComposingText = textView.hasMarkedText()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PromptTextView
        weak var textView: FocusReportingTextView?

        init(_ parent: PromptTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            parent.isComposingText = textView.hasMarkedText()
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }
    }
}

final class FocusReportingTextView: NSTextView {
    var focusChanged: ((Bool) -> Void)?
    var markedTextChanged: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            focusChanged?(true)
        }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            focusChanged?(false)
            markedTextChanged?(false)
        }
        return didResign
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        markedTextChanged?(hasMarkedText())
    }

    override func unmarkText() {
        super.unmarkText()
        markedTextChanged?(hasMarkedText())
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        markedTextChanged?(hasMarkedText())
    }
}
