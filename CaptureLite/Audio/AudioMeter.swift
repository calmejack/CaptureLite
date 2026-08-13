import Foundation
import CoreMedia
import AudioToolbox

enum AudioMeter {
    static func level(from sampleBuffer: CMSampleBuffer) -> Float {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        else { return 0 }

        let channelCount = Int(asbd.mChannelsPerFrame)
        guard channelCount > 0 else { return 0 }

        let bufferListSize = MemoryLayout<AudioBufferList>.size + (channelCount - 1) * MemoryLayout<AudioBuffer>.size
        let raw = UnsafeMutableRawPointer.allocate(byteCount: bufferListSize, alignment: 16)
        defer { raw.deallocate() }
        let bufferList = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        bufferList.pointee.mNumberBuffers = UInt32(channelCount)

        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferList,
            bufferListSize: bufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return 0 }

        let bytesPerSample = Int(asbd.mBitsPerChannel) / 8
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0

        var sumSquares: Double = 0
        var sampleCount: Int = 0

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for buffer in buffers {
            guard let data = buffer.mData, buffer.mDataByteSize > 0 else { continue }
            let count = Int(buffer.mDataByteSize) / bytesPerSample

            if isFloat, bytesPerSample == 4 {
                let samples = data.assumingMemoryBound(to: Float.self)
                for i in 0..<count {
                    let v = samples[i]
                    sumSquares += Double(v * v)
                }
            } else if !isFloat, bytesPerSample == 2 {
                let samples = data.assumingMemoryBound(to: Int16.self)
                for i in 0..<count {
                    let v = Float(samples[i]) / 32768.0
                    sumSquares += Double(v * v)
                }
            } else {
                continue
            }
            sampleCount += count
        }

        guard sampleCount > 0 else { return 0 }
        let rms = sqrt(sumSquares / Double(sampleCount))
        return Float(min(max(rms, 0), 1))
    }
}
