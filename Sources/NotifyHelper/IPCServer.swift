import Foundation
import NotifyShared
import Darwin

class IPCServer {
    private let notificationManager: NotificationManager
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let socketPath: String
    private var acceptThread: Thread?

    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        self.socketPath = Constants.socketPath
    }

    func start() {
        // Ensure socket directory exists
        try? FileManager.default.createDirectory(at: Constants.socketDirectory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: Constants.socketDirectory.path
        )

        // Remove existing socket file
        try? FileManager.default.removeItem(atPath: socketPath)

        // Create socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            NSLog("Failed to create socket")
            return
        }

        // Bind to path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            NSLog("Socket path too long: \(socketPath)")
            close(serverSocket)
            serverSocket = -1
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            for (i, byte) in pathBytes.enumerated() {
                ptr.advanced(by: i).pointee = byte
            }
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            NSLog("Failed to bind socket: \(String(cString: strerror(errno)))")
            close(serverSocket)
            serverSocket = -1
            return
        }

        _ = Darwin.chmod(socketPath, mode_t(0o600))

        // Listen
        guard listen(serverSocket, 5) == 0 else {
            NSLog("Failed to listen on socket")
            close(serverSocket)
            serverSocket = -1
            return
        }

        isRunning = true
        NSLog("IPC server listening on \(socketPath)")

        // Accept connections in background thread
        acceptThread = Thread { [weak self] in
            self?.acceptLoop()
        }
        acceptThread?.start()
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientAddrLen)
                }
            }

            guard clientSocket >= 0 else {
                if isRunning {
                    NSLog("Accept failed: \(String(cString: strerror(errno)))")
                }
                continue
            }

            guard isAuthorizedClient(clientSocket) else {
                NSLog("Rejected unauthorized client connection")
                close(clientSocket)
                continue
            }

            // Handle client in separate thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(socket: clientSocket)
            }
        }
    }

    private func handleClient(socket clientSocket: Int32) {
        defer { close(clientSocket) }

        do {
            // Read request length (4 bytes, big endian)
            var lengthBytes = [UInt8](repeating: 0, count: 4)
            try lengthBytes.withUnsafeMutableBytes { ptr in
                try recvAll(socket: clientSocket, buffer: ptr)
            }

            let requestLength = Int(UInt32(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))
            guard requestLength > 0 && requestLength < 1_000_000 else {
                NSLog("Invalid request length: \(requestLength)")
                return
            }

            // Read request data
            var requestData = Data(count: requestLength)
            try requestData.withUnsafeMutableBytes { ptr in
                try recvAll(socket: clientSocket, buffer: ptr)
            }

            // Decode request
            let decoder = JSONDecoder()
            guard let request = try? decoder.decode(NotificationRequest.self, from: requestData) else {
                NSLog("Failed to decode request")
                sendResponse(to: clientSocket, response: NotificationResponse(
                    success: false,
                    exitCode: ExitCodes.runtimeError,
                    error: "Invalid request format"
                ))
                return
            }

            // Handle request
            let semaphore = DispatchSemaphore(value: 0)
            var response: NotificationResponse!

            switch request.action {
            case .send:
                notificationManager.send(request) { resp in
                    response = resp
                    semaphore.signal()
                }
            case .remove:
                notificationManager.remove(groupID: request.group ?? "ALL") { resp in
                    response = resp
                    semaphore.signal()
                }
            case .list:
                notificationManager.list(groupID: request.group) { resp in
                    response = resp
                    semaphore.signal()
                }
            }

            // Wait for response (with timeout for non-wait requests)
            let timeout: DispatchTime = request.wait ? .distantFuture : .now() + .seconds(30)
            if semaphore.wait(timeout: timeout) == .timedOut {
                response = NotificationResponse(
                    success: false,
                    exitCode: ExitCodes.runtimeError,
                    error: "Request timed out"
                )
            }

            sendResponse(to: clientSocket, response: response)
        } catch {
            NSLog("IPC client handling error: \(error.localizedDescription)")
        }
    }

    private func sendResponse(to socket: Int32, response: NotificationResponse) {
        let encoder = JSONEncoder()
        guard let responseData = try? encoder.encode(response) else {
            NSLog("Failed to encode response")
            return
        }

        do {
            // Send length prefix
            var length = UInt32(responseData.count).bigEndian
            try withUnsafeBytes(of: &length) { ptr in
                try sendAll(socket: socket, buffer: ptr)
            }

            // Send response data
            try responseData.withUnsafeBytes { ptr in
                try sendAll(socket: socket, buffer: ptr)
            }
        } catch {
            NSLog("Failed to send response: \(error.localizedDescription)")
        }
    }

    private func isAuthorizedClient(_ clientSocket: Int32) -> Bool {
        var euid: uid_t = 0
        var egid: gid_t = 0
        if getpeereid(clientSocket, &euid, &egid) != 0 {
            return false
        }
        return euid == getuid()
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
                throw NSError(domain: "IPCServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Socket closed while sending"])
            }
            if errno == EINTR {
                continue
            }
            throw NSError(domain: "IPCServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
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
                throw NSError(domain: "IPCServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Socket closed while receiving"])
            }
            if errno == EINTR {
                continue
            }
            throw NSError(domain: "IPCServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
        }
    }
}
