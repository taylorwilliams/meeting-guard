import Foundation

public enum SoundRepeatMode: String, CaseIterable, Codable, Sendable {
    case once, untilAnswered, forDuration
}

@MainActor
public protocol AlertSoundOutput: AnyObject {
    func play(name: String, volume: Double, loops: Bool) -> Bool
    func stop()
}

/// Owns the audible session independently of alert-window layout. A redraw or a
/// second queued meeting must not restart the current sound or extend its limit.
@MainActor
public final class AlertSoundController {
    private let output: any AlertSoundOutput
    private let clock: () -> TimeInterval
    private var activeAlertID: String?
    private var deadline: TimeInterval?
    public var needsTimer: Bool { deadline != nil }

    public init(output: any AlertSoundOutput, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.output = output
        self.clock = clock
    }

    @discardableResult
    public func start(alertID: String, settings: GuardSettings) -> Bool {
        guard settings.playSound else { stop(); return true }
        guard activeAlertID != alertID else { return true }
        stop()
        activeAlertID = alertID
        if settings.soundPlaybackMode == .forDuration { deadline = clock() + settings.repeatDurationSeconds }
        let volume = settings.soundVolume.isFinite ? min(1, max(0, settings.soundVolume)) : 0.6
        let started = output.play(name: settings.soundName, volume: volume, loops: settings.soundPlaybackMode != .once)
        if !started { deadline = nil }
        return started
    }

    public func tick() {
        if let deadline, clock() >= deadline {
            output.stop()
            self.deadline = nil
            // Keep the ID: a redraw after expiry must not start another session.
        }
    }

    public func stop() {
        output.stop()
        activeAlertID = nil
        deadline = nil
    }
}
