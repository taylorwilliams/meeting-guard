import Foundation

/// An original mechanical-siren style wail. The fundamental sweeps smoothly
/// from 200 to 900 Hz and back; integer cycles keep loop boundaries continuous.
public enum AirRaidSiren {
    public static let sampleRate = 22050
    public static let cycleSeconds = 8
    public static let waveData = PCM16Wave.make(sampleRate: sampleRate, seconds: cycleSeconds) { time in
        let sweep = 2 * Double.pi * time / Double(cycleSeconds)
        let phase = 2 * Double.pi * 550 * time - 350 * Double(cycleSeconds) * sin(sweep)
        let fundamental = 0.6 * sin(phase)
        let harmonics = 0.2 * sin(2 * phase) + 0.1 * sin(3 * phase) + 0.04 * sin(4 * phase)
        return (fundamental + harmonics) * 0.85
    }
}
