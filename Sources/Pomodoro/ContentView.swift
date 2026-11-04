import AppKit
import PomodoroKit
import SwiftUI

/// The menu-bar tray: all controls live here, so the floating timer can stay
/// visually quiet and never needs a title bar or toolbar.
struct MenuBarView: View {
    @ObservedObject var model: PomodoroModel
    @State private var showShortcuts = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
            timerControls
            Divider()
            phaseControls
            durationControls
            Divider()
            shortcutControls
            Divider()
            displayControls
            Divider()
            footer
        }
        .padding(Space.lg)
        .frame(width: 340)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: model.phaseSymbol)
                .foregroundStyle(.tint)
            Text(model.phaseTitle)
                .font(.headline)
            Spacer()
            Text(model.formattedRemaining)
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .fontWeight(.semibold)
        }
    }

    private var timerControls: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ProgressView(value: model.progress)
                .controlSize(.small)
            HStack(spacing: Space.sm) {
                Button(model.isRunning ? "Pause" : "Start") {
                    model.toggleRunning()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button("Reset") { model.reset() }
                Button("Skip") { model.skip() }
                Spacer()
                Text("\(model.completedFocusSessions) focus sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var phaseControls: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Timer")
                .font(.subheadline.weight(.semibold))
            Picker("Phase", selection: Binding(
                get: { model.phase },
                set: { model.choose($0) }
            )) {
                ForEach(PomodoroTimer.Phase.allCases, id: \.self) { phase in
                    Text(phase.title).tag(phase)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Stepper(value: Binding(
                get: { model.longBreakEvery },
                set: { model.longBreakEvery = $0 }
            ), in: 2...12) {
                Text("Long break after \(model.longBreakEvery) focus sessions")
                    .font(.caption)
            }
        }
    }

    private var durationControls: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Durations")
                .font(.subheadline.weight(.semibold))
            DurationRow(title: "Focus", minutes: Binding(
                get: { model.workMinutes },
                set: { model.workMinutes = $0 }
            ), range: 1...180)
            DurationRow(title: "Short break", minutes: Binding(
                get: { model.shortBreakMinutes },
                set: { model.shortBreakMinutes = $0 }
            ), range: 1...60)
            DurationRow(title: "Long break", minutes: Binding(
                get: { model.longBreakMinutes },
                set: { model.longBreakMinutes = $0 }
            ), range: 1...120)
        }
    }

    private var shortcutControls: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showShortcuts.toggle() }
            } label: {
                HStack {
                    Text("Shortcuts")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showShortcuts ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shortcuts")
            .accessibilityValue(showShortcuts ? "Expanded" : "Collapsed")

            if showShortcuts {
                ForEach(ShortcutAction.allCases) { action in
                    HStack {
                        Text(action.title)
                        Spacer()
                        ShortcutRecorder(action: action, model: model)
                    }
                    .font(.callout)
                }
                HStack {
                    Text("Click a shortcut, then press a new combination. Esc cancels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Defaults") { model.restoreDefaultShortcuts() }
                        .controlSize(.small)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private var displayControls: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Floating timer")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int((model.timerScale * 100).rounded()))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: Binding(
                    get: { model.timerScale },
                    set: { model.timerScale = $0 }
                ), in: 0.6...2.6, step: 0.1)
            }
            HStack {
                Text("Adaptive color")
                Spacer()
                Text(model.hasScreenAccess ? "On" : "Permission needed")
                    .foregroundStyle(.secondary)
            }
            if !model.hasScreenAccess {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Allow Screen Recording once so the timer can match the background behind it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Space.sm) {
                        Button("Open Screen Recording Settings") { model.openScreenRecordingSettings() }
                    }
                    .controlSize(.small)
                }
            }
            Toggle("Click-through timer", isOn: Binding(
                get: { model.clickThrough },
                set: { model.clickThrough = $0 }
            ))
            Text("Drag the timer to move it. Click-through keeps it from blocking clicks.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Button("Reset cycle") { model.resetCycle() }
                .controlSize(.small)
            Spacer()
            Button("Quit Pomodoro") { NSApp.terminate(nil) }
                .controlSize(.small)
        }
    }

}

private struct DurationRow: View {
    let title: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: $minutes, in: range) {
                Text("\(minutes) min")
                    .monospacedDigit()
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
        .font(.callout)
    }
}
