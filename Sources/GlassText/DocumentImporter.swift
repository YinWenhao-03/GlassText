import AppKit
import PDFKit

final class ImportJob: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var stopped = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func cancel() {
        lock.lock(); stopped = true; let running = process; lock.unlock()
        if let running = running, running.isRunning { running.terminate() }
    }
    func run(_ executable: URL, arguments: [String], output: URL, timeout: Double = 45) throws {
        let task = Process(); task.executableURL = executable; task.arguments = arguments
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output); defer { try? handle.close() }
        task.standardOutput = handle; task.standardError = FileHandle.nullDevice
        lock.lock()
        if stopped { lock.unlock(); throw ImportFailure.cancelled }
        do { try task.run(); process = task; lock.unlock() } catch { lock.unlock(); throw error }
        let deadline = Date().addingTimeInterval(timeout)
        var timedOut = false
        while task.isRunning {
            if cancelled || Date() >= deadline {
                timedOut = !cancelled; task.terminate()
                Thread.sleep(forTimeInterval: 0.2)
                if task.isRunning { kill(task.processIdentifier, SIGKILL) }
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        task.waitUntilExit(); lock.lock(); process = nil; lock.unlock()
        if timedOut { throw ImportFailure.timeout }
        if cancelled { throw ImportFailure.cancelled }
        guard task.terminationStatus == 0 else { throw ImportFailure.conversion }
    }
}
enum ImportFailure: LocalizedError {
    case cancelled, timeout, conversion, empty, large, format, encrypted, missingConverter
    var errorDescription: String? {
        switch self {
        case .cancelled: return "读取已取消。"
        case .timeout: return "转换超过 45 秒已停止，请缩小文档或直接打开 PDF。"
        case .conversion: return "文档转换失败，请检查文件是否损坏或加密。"
        case .empty: return "文档没有可显示内容。"
        case .large: return "文档超过当前处理上限（文件 100 MB、纯文字 200 万字符），请拆分后打开。"
        case .format: return "文件格式不受支持或文件已损坏。"
        case .encrypted: return "PDF 已加密，请解锁后重新打开。"
        case .missingConverter: return "保留 Word 版式需要在“应用程序”中安装 LibreOffice。也可选择提取文字，或在 Word 中导出 PDF。"
        }
    }
}
enum DocumentImporter {
    static func read(_ url: URL, job: ImportJob, preserveLayout: Bool) throws -> App.Loaded {
        let ext = url.pathExtension.lowercased()
        guard ["pdf","doc","docx","rtf","txt","md"].contains(ext) else { throw ImportFailure.format }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 100*1024*1024 else { throw ImportFailure.large }
        if job.cancelled { throw ImportFailure.cancelled }
        func pdf(_ url: URL) throws -> App.Loaded {
            guard let doc = PDFDocument(url: url) else { throw ImportFailure.format }
            guard !doc.isLocked else { throw ImportFailure.encrypted }
            guard doc.pageCount > 0 else { throw ImportFailure.empty }
            return .pdf(doc)
        }
        if ext == "pdf" { return try pdf(url) }
        var text: String
        if ["doc", "docx", "rtf"].contains(ext) {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GlassText-"+UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let output = directory.appendingPathComponent("output.txt")
            if preserveLayout {
                let executable = URL(fileURLWithPath: "/Applications/LibreOffice.app/Contents/MacOS/soffice")
                guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw ImportFailure.missingConverter }
                let input = directory.appendingPathComponent("document."+ext); try FileManager.default.copyItem(at: url, to: input)
                let profile = directory.appendingPathComponent("profile").absoluteString
                try job.run(executable, arguments: ["-env:UserInstallation="+profile,"--headless","--convert-to","pdf","--outdir",directory.path,input.path], output: output)
                let converted = directory.appendingPathComponent("document.pdf")
                // Detach from the temporary output before it is removed.
                guard let document = PDFDocument(data: try Data(contentsOf: converted)), document.pageCount > 0 else { throw ImportFailure.conversion }
                return .pdf(document)
            }
            try job.run(URL(fileURLWithPath: "/usr/bin/textutil"), arguments: ["-convert","txt","-stdout",url.path], output: output)
            text = try String(contentsOf: output, encoding: .utf8)
        } else { text = try String(contentsOf: url) }
        if job.cancelled { throw ImportFailure.cancelled }
        guard text.utf16.count <= 2_000_000 else { throw ImportFailure.large }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportFailure.empty }
        return .text(text)
    }
}
