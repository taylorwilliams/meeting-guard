import Foundation

/// Four rounded pulses blending a low body with a clear upper horn note.
public enum DeepBassPulse {
    public static let sampleRate = 22050
    public static let cycleSeconds = 6
    public static let waveData = PCM16Wave.make(sampleRate: sampleRate, seconds: cycleSeconds) { time in
        let position = time.truncatingRemainder(dividingBy: 1.5)
        guard position < 0.95 else { return 0 }
        let attack = min(1, position / 0.07)
        let release = min(1, (0.95 - position) / 0.3)
        let envelope = pow(sin(attack * .pi / 2), 2) * pow(sin(release * .pi / 2), 2)
        let pitchTime = position + 0.0144 * (1 - exp(-position / 0.12))
        let phase = 2 * Double.pi * pitchTime
        let body = 0.21 * sin(65.406 * phase) + 0.15 * sin(87.307 * phase)
        let middle = 0.22 * sin(196.218 * phase) + 0.16 * sin(261.624 * phase)
        let upperPhase = 2 * Double.pi * position
        let horn = 0.14 * sin(523.25 * upperPhase) + 0.06 * sin(784.875 * upperPhase)
        return (body + middle + horn) * envelope * 0.84
    }
}
