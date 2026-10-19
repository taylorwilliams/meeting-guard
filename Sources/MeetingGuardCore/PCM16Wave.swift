import Foundation

enum PCM16Wave {
    static func make(sampleRate: Int, seconds: Int, sample: (Double) -> Double) -> Data {
        let sampleCount = sampleRate * seconds
        let byteCount = sampleCount * 2
        var data = Data(capacity: 44 + byteCount)
        func ascii(_ text: String) { data.append(contentsOf: text.utf8) }
        func word(_ value: UInt16) {
            data.append(UInt8(value & 255)); data.append(UInt8(value >> 8))
        }
        func dword(_ value: UInt32) {
            word(UInt16(value & 65535)); word(UInt16(value >> 16))
        }
        ascii("RIFF"); dword(UInt32(36 + byteCount)); ascii("WAVE")
        ascii("fmt "); dword(16); word(1); word(1)
        dword(UInt32(sampleRate)); dword(UInt32(sampleRate * 2)); word(2); word(16)
        ascii("data"); dword(UInt32(byteCount))
        for index in 0..<sampleCount {
            let value = min(1, max(-1, sample(Double(index) / Double(sampleRate))))
            word(UInt16(bitPattern: Int16((value * Double(Int16.max)).rounded())))
        }
        return data
    }
}
