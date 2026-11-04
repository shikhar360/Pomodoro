import Testing
@testable import PomodoroKit

@Test("Shortcut display follows Mac modifier order")
func shortcutDisplay() {
    #expect(Shortcut(keyCode: 1, modifiers: .function).display == "fn S")
    #expect(Shortcut(keyCode: 35, modifiers: [.command, .shift]).display == "⇧ ⌘ P")
    #expect(Shortcut(keyCode: 15, modifiers: [.control, .option]).display == "⌃ ⌥ R")
}

@Test("A letter needs a modifier, a function key does not")
func shortcutUsability() {
    #expect(!Shortcut(keyCode: 1, modifiers: []).isUsable)
    #expect(Shortcut(keyCode: 1, modifiers: .function).isUsable)
    #expect(Shortcut(keyCode: 122, modifiers: []).isUsable)
}

@Test("Defaults are fn-S, fn-P, fn-R, and control-K")
func defaultShortcuts() {
    #expect(ShortcutAction.start.defaultShortcut == Shortcut(keyCode: 1, modifiers: .function))
    #expect(ShortcutAction.pause.defaultShortcut == Shortcut(keyCode: 35, modifiers: .function))
    #expect(ShortcutAction.reset.defaultShortcut == Shortcut(keyCode: 15, modifiers: .function))
    #expect(ShortcutAction.skip.defaultShortcut == Shortcut(keyCode: 40, modifiers: .control))
    #expect(ShortcutAction.skip.defaultShortcut.display == "⌃ K")
}
