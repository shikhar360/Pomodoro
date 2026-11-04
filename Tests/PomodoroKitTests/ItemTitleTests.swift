import Testing
@testable import PomodoroKit

@Test("Clock formats minutes and seconds")
func clockFormats() {
    #expect(PomodoroTimer.clock(1_500) == "25:00")
    #expect(PomodoroTimer.clock(249) == "4:09")
    #expect(PomodoroTimer.clock(0.2) == "0:01")
    #expect(PomodoroTimer.clock(-4) == "0:00")
}

@Test("Durations stay inside a useful range")
func durationsClamp() {
    #expect(PomodoroTimer.minutes(for: .work, work: 0, shortBreak: 5, longBreak: 15) == 1)
    #expect(PomodoroTimer.minutes(for: .work, work: 500, shortBreak: 5, longBreak: 15) == 180)
    #expect(PomodoroTimer.minutes(for: .shortBreak, work: 25, shortBreak: 5, longBreak: 15) == 5)
}

@Test("A long break comes after the chosen number of focus sessions")
func longBreakCycle() {
    #expect(PomodoroTimer.next(after: .work, completedFocusSessions: 1, longBreakEvery: 4) == .shortBreak)
    #expect(PomodoroTimer.next(after: .work, completedFocusSessions: 4, longBreakEvery: 4) == .longBreak)
    #expect(PomodoroTimer.next(after: .work, completedFocusSessions: 8, longBreakEvery: 4) == .longBreak)
    #expect(PomodoroTimer.next(after: .shortBreak, completedFocusSessions: 4, longBreakEvery: 4) == .work)
    #expect(PomodoroTimer.next(after: .longBreak, completedFocusSessions: 4, longBreakEvery: 4) == .work)
}

@Test("Progress runs from zero to one")
func progressRange() {
    #expect(PomodoroTimer.progress(remaining: 1_500, duration: 1_500) == 0)
    #expect(PomodoroTimer.progress(remaining: 750, duration: 1_500) == 0.5)
    #expect(PomodoroTimer.progress(remaining: 0, duration: 1_500) == 1)
    #expect(PomodoroTimer.progress(remaining: 10, duration: 0) == 0)
}

@Test("Dark backgrounds get white digits and light ones get black digits")
func adaptiveTextColor() {
    #expect(PomodoroTimer.usesLightText(forBackgroundLightness: 0))
    #expect(PomodoroTimer.usesLightText(forBackgroundLightness: 0.5))
    #expect(!PomodoroTimer.usesLightText(forBackgroundLightness: 0.5001))
    #expect(!PomodoroTimer.usesLightText(forBackgroundLightness: 1))
}
