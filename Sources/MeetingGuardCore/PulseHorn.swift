import Foundation

/// Four even, fixed-pitch "DAAA" blasts. Repeating the clip keeps the same
/// one-second rhythm with no extra gap between clips.
public enum PulseHorn {
    public static let sampleRate = 22050
    public static let cycleSeconds = 4
    public static let waveData = PCM16Wave.make(sampleRate: sampleRate, seconds: cycleSeconds) { time in
        let position = time.truncatingRemainder(dividingBy: 1)
        guard position < 0.7 else { return 0 }
        let attack = min(1, position / 0.025)
        let release = min(1, (0.7 - position) / 0.065)
        let envelope = pow(sin(attack * .pi / 2), 2) * pow(sin(release * .pi / 2), 2)
        let phase = 2 * Double.pi * position
        let body = 0.45 * sin(330 * phase) + 0.25 * sin(440 * phase)
        let harmonics = 0.16 * sin(660 * phase) + 0.08 * sin(880 * phase)
        return (body + harmonics) * envelope * 0.85
    }
}
