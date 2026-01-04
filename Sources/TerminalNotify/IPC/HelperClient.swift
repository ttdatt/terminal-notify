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
            throw ClientError.helperNotRunning
        }

        // Send request as JSON
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)

        // Send length prefix (4 bytes, big endian)
        var length = UInt32(requestData.count).bigEndian
        let lengthSent = withUnsafeBytes(of: &length) { ptr in
            Darwin.send(socket, ptr.baseAddress!, 4, 0)
        }
        guard lengthSent == 4 else {
            throw ClientError.communicationError("Failed to send request length")
        }

        // Send request data
        let dataSent = requestData.withUnsafeBytes { ptr in
            Darwin.send(socket, ptr.baseAddress!, requestData.count, 0)
        }
        guard dataSent == requestData.count else {
            throw ClientError.communicationError("Failed to send request data")
        }

        // Receive response length
        var responseLengthBytes = [UInt8](repeating: 0, count: 4)
        let lengthReceived = recv(socket, &responseLengthBytes, 4, 0)
        guard lengthReceived == 4 else {
            throw ClientError.communicationError("Failed to receive response length")
        }

        let responseLength = Int(UInt32(bigEndian: responseLengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))
        guard responseLength > 0 && responseLength < 1_000_000 else {
            throw ClientError.communicationError("Invalid response length")
        }

        // Receive response data
        var responseData = Data(count: responseLength)
        let dataReceived = responseData.withUnsafeMutableBytes { ptr in
            recv(socket, ptr.baseAddress!, responseLength, 0)
        }
        guard dataReceived == responseLength else {
            throw ClientError.communicationError("Failed to receive response data")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(NotificationResponse.self, from: responseData)
    }
}
