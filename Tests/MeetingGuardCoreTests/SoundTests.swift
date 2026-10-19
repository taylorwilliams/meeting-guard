import AVFAudio
import Foundation
import Testing
@testable import MeetingGuardCore

@MainActor
private final class SoundProbe: AlertSoundOutput {
    var plays: [(String, Double, Bool)] = []
    var stops = 0
    var playing = false
    var available = true
    func play(name: String, volume: Double, loops: Bool) -> Bool {
        plays.append((name, volume, loops)); playing = available; return available
    }
    func stop() { stops += 1; playing = false }
}

@MainActor
private final class SoundClock { var seconds: TimeInterval = 0 }

@Test @MainActor func timedSoundStopsAtTwoMinutesWithoutDismissingTheAlert() {
    let output = SoundProbe(); let clock = SoundClock()
    let controller = AlertSoundController(output: output, clock: { clock.seconds })
    var settings = GuardSettings(); settings.soundPlaybackMode = .forDuration; settings.repeatDurationSeconds = 120
    #expect(controller.start(alertID: "meeting", settings: settings))
    #expect(output.playing)
    #expect(output.plays.first?.2 == true)
    clock.seconds = 119.9; controller.tick()
    #expect(output.playing)
    clock.seconds = 120; controller.tick()
    #expect(!output.playing)
    #expect(controller.start(alertID: "meeting", settings: settings))
    #expect(output.plays.count == 1)
}

@Test @MainActor func redrawingAnAlertOrQueuingAnotherDoesNotExtendSound() {
    let output = SoundProbe(); let clock = SoundClock()
    let controller = AlertSoundController(output: output, clock: { clock.seconds })
    let settings = GuardSettings()
    controller.start(alertID: "first", settings: settings)
    clock.seconds = 90
    controller.start(alertID: "first", settings: settings)
    #expect(output.plays.count == 1)
    clock.seconds = 120; controller.tick()
    #expect(!output.playing)
    controller.start(alertID: "second", settings: settings)
    #expect(output.playing)
    clock.seconds = 239; controller.tick()
    #expect(output.playing)
    clock.seconds = 240; controller.tick()
    #expect(!output.playing)
}

@Test @MainActor func repeatUntilAnsweredHasNoTimeLimitButStopsOnAcknowledgement() {
    let output = SoundProbe(); let clock = SoundClock()
    let controller = AlertSoundController(output: output, clock: { clock.seconds })
    var settings = GuardSettings(); settings.soundPlaybackMode = .untilAnswered
    controller.start(alertID: "meeting", settings: settings)
    clock.seconds = 86400; controller.tick()
    #expect(output.playing)
    #expect(output.plays.first?.2 == true)
    controller.stop()
    #expect(!output.playing)
    clock.seconds += 86400; controller.tick()
    #expect(output.plays.count == 1)
}

@Test @MainActor func customDurationAndEarlyDismissalBothStopSound() {
    let output = SoundProbe(); let clock = SoundClock()
    let controller = AlertSoundController(output: output, clock: { clock.seconds })
    var settings = GuardSettings(); settings.repeatDurationSeconds = 30
    controller.start(alertID: "thirty-seconds", settings: settings)
    clock.seconds = 30; controller.tick()
    #expect(!output.playing)
    controller.start(alertID: "dismissed", settings: settings)
    clock.seconds = 31; controller.stop()
    #expect(!output.playing)
    clock.seconds = 90; controller.tick()
    #expect(output.plays.count == 2)
}

@Test @MainActor func playOnceDoesNotLoopAndDisabledSoundNeverPlays() {
    let output = SoundProbe()
    let controller = AlertSoundController(output: output)
    var settings = GuardSettings(); settings.soundPlaybackMode = .once
    controller.start(alertID: "once", settings: settings)
    #expect(output.plays.first?.2 == false)
    settings.playSound = false
    controller.start(alertID: "muted", settings: settings)
    #expect(output.plays.count == 1)
    #expect(!output.playing)
}

@Test @MainActor func unavailableSoundReportsFailure() {
    let output = SoundProbe(); output.available = false
    let controller = AlertSoundController(output: output)
    #expect(!controller.start(alertID: "meeting", settings: .init()))
    #expect(!output.playing)
}

@Test func oldSoundPreferencesDecodeWithoutLosingCalendarChoices() throws {
    var original = GuardSettings()
    original.disabledCalendars = ["personal"]
    original.soundName = "Glass"
    var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
    old.removeValue(forKey: "soundRepeatMode"); old.removeValue(forKey: "soundRepeatSeconds")
    for (repeatSound, expected) in [(false, SoundRepeatMode.once), (true, .untilAnswered)] {
        old["repeatSound"] = repeatSound
        let migrated = try JSONDecoder().decode(GuardSettings.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(migrated.soundPlaybackMode == expected)
        #expect(migrated.repeatDurationSeconds == 120)
        #expect(migrated.disabledCalendars == ["personal"])
        #expect(migrated.soundName == "Glass")
    }
}

@Test func soundModesAndCustomDurationSurviveSaving() throws {
    for mode in SoundRepeatMode.allCases {
        var settings = GuardSettings()
        settings.soundPlaybackMode = mode; settings.repeatDurationSeconds = 45
        let restored = try JSONDecoder().decode(GuardSettings.self, from: JSONEncoder().encode(settings))
        #expect(restored.soundPlaybackMode == mode)
        #expect(restored.repeatDurationSeconds == 45)
    }
    var settings = GuardSettings()
    settings.repeatDurationSeconds = -.infinity
    #expect(settings.repeatDurationSeconds == 120)
    settings.repeatDurationSeconds = -30
    #expect(settings.repeatDurationSeconds == 1)
}

@Test func foghornIsAPlayableOriginalAudioCycleWithAQuietGap() throws {
    let player = try AVAudioPlayer(data: Foghorn.waveData)
    #expect(abs(player.duration - 8) < 0.001)
    #expect(player.numberOfChannels == 1)
    let data = [UInt8](Foghorn.waveData)
    #expect(String(bytes: data.prefix(4), encoding: .ascii) == "RIFF")
    #expect(data.count == 44 + 22050 * 8 * 2)
    let samples = stride(from: 44, to: data.count, by: 2).map { index in
        Double(Int16(bitPattern: UInt16(data[index]) | UInt16(data[index + 1]) << 8)) / Double(Int16.max)
    }
    #expect(samples.allSatisfy { abs($0) < 0.95 })
    #expect(samples.suffix(2 * Foghorn.sampleRate).allSatisfy { $0 == 0 })
    let body = Array(samples[Foghorn.sampleRate..<(2 * Foghorn.sampleRate)])
    func energy(at frequency: Double) -> Double {
        var real = 0.0; var imaginary = 0.0
        for (index, sample) in body.enumerated() {
            let phase = 2 * Double.pi * frequency * Double(index) / Double(Foghorn.sampleRate)
            real += sample * cos(phase); imaginary += sample * sin(phase)
        }
        return real * real + imaginary * imaginary
    }
    #expect(energy(at: 110) > energy(at: 1800) * 100)
    #expect(energy(at: 146.83) > energy(at: 1800) * 100)
}

@Test func airRaidSirenIsPlayableAndRisesThenFallsWithoutClipping() throws {
    let player = try AVAudioPlayer(data: AirRaidSiren.waveData)
    #expect(abs(player.duration - 8) < 0.001)
    let data = [UInt8](AirRaidSiren.waveData)
    let samples = stride(from: 44, to: data.count, by: 2).map { index in
        Double(Int16(bitPattern: UInt16(data[index]) | UInt16(data[index + 1]) << 8)) / Double(Int16.max)
    }
    #expect(samples.allSatisfy { abs($0) < 0.95 })
    func cycles(from start: Double, to end: Double) -> Int {
        let lower = max(1, Int(start * Double(AirRaidSiren.sampleRate)))
        let upper = min(samples.count, Int(end * Double(AirRaidSiren.sampleRate)))
        return (lower..<upper).filter { samples[$0 - 1] <= 0 && samples[$0] > 0 }.count
    }
    let beginning = cycles(from: 0, to: 0.5)
    let peak = cycles(from: 3.75, to: 4.25)
    let ending = cycles(from: 7.5, to: 8)
    #expect(peak > beginning * 3)
    #expect(abs(ending - beginning) <= 2)
}

@Test func pulseHornHasFourEvenBlastsWithShortQuietGaps() throws {
    let player = try AVAudioPlayer(data: PulseHorn.waveData)
    #expect(abs(player.duration - 4) < 0.001)
    let data = [UInt8](PulseHorn.waveData)
    let samples = stride(from: 44, to: data.count, by: 2).map { index in
        Double(Int16(bitPattern: UInt16(data[index]) | UInt16(data[index + 1]) << 8)) / Double(Int16.max)
    }
    #expect(samples.allSatisfy { abs($0) < 0.95 })
    for blast in 0..<4 {
        let start = blast * PulseHorn.sampleRate
        let body = samples[(start + 2205)..<(start + 13230)]
        #expect(body.reduce(0) { $0 + $1 * $1 } / Double(body.count) > 0.02)
        #expect(samples[(start + 17640)..<(start + PulseHorn.sampleRate)].allSatisfy { $0 == 0 })
    }
}

@Test func deepBassPulseIsLowPitchedAndHasFourSlowerBlasts() throws {
    let player = try AVAudioPlayer(data: DeepBassPulse.waveData)
    #expect(abs(player.duration - 6) < 0.001)
    let data = [UInt8](DeepBassPulse.waveData)
    let samples = stride(from: 44, to: data.count, by: 2).map { index in
        Double(Int16(bitPattern: UInt16(data[index]) | UInt16(data[index + 1]) << 8)) / Double(Int16.max)
    }
    #expect(samples.allSatisfy { abs($0) < 0.95 })
    for blast in 0..<4 {
        let start = Int(Double(blast) * 1.5 * Double(DeepBassPulse.sampleRate))
        let body = samples[(start + 4410)..<(start + 11025)]
        #expect(body.reduce(0) { $0 + $1 * $1 } / Double(body.count) > 0.02)
        #expect(samples[(start + 22050)..<(start + 33075)].allSatisfy { $0 == 0 })
    }
    let body = Array(samples[4410..<13230])
    func energy(at frequency: Double) -> Double {
        var real = 0.0; var imaginary = 0.0
        for (index, sample) in body.enumerated() {
            let phase = 2 * Double.pi * frequency * Double(index) / Double(DeepBassPulse.sampleRate)
            real += sample * cos(phase); imaginary += sample * sin(phase)
        }
        return real * real + imaginary * imaginary
    }
    #expect(energy(at: 65.406) > energy(at: 330) * 20)
    #expect(energy(at: 523.25) > energy(at: 1000) * 20)
}
