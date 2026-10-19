import Foundation

/// An original, synthesised low two-tone horn. One cycle contains a long blast
/// and a quiet gap; playback repeats the cycle according to the user's settings.
public enum Foghorn {
    public static let sampleRate = 22050
    public static let cycleSeconds = 8
    public static let blastSeconds = 5.5

    public static let waveData = PCM16Wave.make(sampleRate: sampleRate, seconds: cycleSeconds) { time in
        guard time < blastSeconds else { return 0 }
        let attack = min(1, time / 0.35)
        let release = min(1, (blastSeconds - time) / 0.8)
        let envelope = pow(sin(attack * .pi / 2), 2) * pow(sin(release * .pi / 2), 2)
        let phase = 2 * Double.pi * time
        let body = 0.46 * sin(phase * 110) + 0.24 * sin(phase * 146.83)
        let harmonics = 0.13 * sin(phase * 220) + 0.07 * sin(phase * 293.66) + 0.04 * sin(phase * 330)
        let breath = 0.96 + 0.04 * sin(phase * 0.7)
        return (body + harmonics) * envelope * breath * 0.9
    }
}
