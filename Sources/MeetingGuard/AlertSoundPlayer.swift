import AppKit
import AVFAudio
import MeetingGuardCore

@MainActor
final class MacSoundOutput: AlertSoundOutput {
    private var horn: AVAudioPlayer?
    private var systemSound: NSSound?

    func play(name: String, volume: Double, loops: Bool) -> Bool {
        stop()
        let waveform: Data?
        switch name {
        case "Foghorn": waveform = Foghorn.waveData
        case "Air Raid Siren": waveform = AirRaidSiren.waveData
        case "Pulse Horn": waveform = PulseHorn.waveData
        case "Deep Bass Pulse": waveform = DeepBassPulse.waveData
        default: waveform = nil
        }
        if let waveform {
            do {
                let player = try AVAudioPlayer(data: waveform)
                player.volume = Float(volume)
                player.numberOfLoops = loops ? -1 : 0
                horn = player
                return player.play()
            } catch { return false }
        }
        guard ["Glass", "Ping", "Hero", "Pop", "Submarine"].contains(name),
              let sound = NSSound(named: NSSound.Name(name)) else { return false }
        sound.volume = Float(volume)
        sound.loops = loops
        systemSound = sound
        return sound.play()
    }

    func stop() {
        horn?.stop(); horn = nil
        systemSound?.stop(); systemSound = nil
    }
}

@MainActor
final class AlertSoundPlayer {
    private let controller = AlertSoundController(output: MacSoundOutput())
    private var timer: Timer?

    @discardableResult
    func start(alertID: String, settings: GuardSettings) -> Bool {
        let started = controller.start(alertID: alertID, settings: settings)
        if timer == nil && controller.needsTimer {
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        return started
    }

    func stop() {
        timer?.invalidate(); timer = nil
        controller.stop()
    }

    private func tick() {
        controller.tick()
        if !controller.needsTimer { timer?.invalidate(); timer = nil }
    }
}
