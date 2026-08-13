import Foundation

actor VideoPipeline {
    private var task: Task<Void, Never>?
    private var renderer: (any VideoRenderer)?
    private var recorder: Recorder?

    func setRenderer(_ renderer: (any VideoRenderer)?) {
        self.renderer = renderer
    }

    func setRecorder(_ recorder: Recorder?) {
        self.recorder = recorder
    }

    func run(source: VideoSource) {
        task?.cancel()
        task = Task {
            for await frame in source.frames {
                if Task.isCancelled { break }
                renderer?.enqueue(frame)
                await recorder?.appendVideo(frame)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
