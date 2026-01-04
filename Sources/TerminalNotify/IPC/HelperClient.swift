import Foundation
import NotifyShared

class HelperClient {
    enum ClientError: LocalizedError {
        case helperNotRunning
        case connectionFailed(String)
        case communicationError(String)

        var errorDescription: String? {
            switch self {
            case .helperNotRunning:
                return "Helper app is not running. Please start terminal-notify-helper.app first."
            case .connectionFailed(let msg):
                return "Failed to connect to helper: \(msg)"
            case .communicationError(let msg):
                return "Communication error: \(msg)"
            }
        }
    }

    private let socketPath: String

    init() {
        self.socketPath = Constants.socketPath
    }

    func send(_ request: NotificationRequest) throws -> NotificationResponse {
        // Ensure socket directory exists
        try? FileManager.default.createDirectory(at: Constants.socketDirectory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: Constants.socketDirectory.path
        )

        // Try to connect
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw ClientError.connectionFailed("Failed to create socket")
        }
        defer { close(socket) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw ClientError.connectionFailed("Socket path too long")
        }

        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            for (i, byte) in pathBytes.enumerated() {
                ptr.advanced(by: i).pointee = byte
            }
        }

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            let connectErrno = errno
            switch connectErrno {
            case ENOENT, ECONNREFUSED:
                throw ClientError.helperNotRunning
            default:
                throw ClientError.connectionFailed(String(cString: strerror(connectErrno)))
            }
        }

        // Send request as JSON
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)

        // Send length prefix (4 bytes, big endian)
        var length = UInt32(requestData.count).bigEndian
        try withUnsafeBytes(of: &length) { ptr in
            try sendAll(socket: socket, buffer: ptr)
        }

        // Send request data
        try requestData.withUnsafeBytes { ptr in
            try sendAll(socket: socket, buffer: ptr)
        }

        // Receive response length
        var responseLengthBytes = [UInt8](repeating: 0, count: 4)
        try responseLengthBytes.withUnsafeMutableBytes { ptr in
            try recvAll(socket: socket, buffer: ptr)
        }

        let responseLength = Int(UInt32(bigEndian: responseLengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))
        guard responseLength > 0 && responseLength < 1_000_000 else {
            throw ClientError.communicationError("Invalid response length")
        }

        // Receive response data
        var responseData = Data(count: responseLength)
        try responseData.withUnsafeMutableBytes { ptr in
            try recvAll(socket: socket, buffer: ptr)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(NotificationResponse.self, from: responseData)
    }

    private func sendAll(socket: Int32, buffer: UnsafeRawBufferPointer) throws {
        var totalSent = 0
        while totalSent < buffer.count {
            let sent = Darwin.send(socket, buffer.baseAddress!.advanced(by: totalSent), buffer.count - totalSent, 0)
            if sent > 0 {
                totalSent += sent
                continue
            }
            if sent == 0 {
                throw ClientError.communicationError("Socket closed while sending")
            }
            if errno == EINTR {
                continue
            }
            throw ClientError.communicationError(String(cString: strerror(errno)))
        }
    }

    private func recvAll(socket: Int32, buffer: UnsafeMutableRawBufferPointer) throws {
        var totalRead = 0
        while totalRead < buffer.count {
            let readCount = recv(socket, buffer.baseAddress!.advanced(by: totalRead), buffer.count - totalRead, 0)
            if readCount > 0 {
                totalRead += readCount
                continue
            }
            if readCount == 0 {
                throw ClientError.communicationError("Socket closed while receiving")
            }
            if errno == EINTR {
                continue
            }
            throw ClientError.communicationError(String(cString: strerror(errno)))
        }
    }
}
