import Foundation
import NotifyShared

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
            return
        }

        // Listen
        guard listen(serverSocket, 5) == 0 else {
            NSLog("Failed to listen on socket")
            close(serverSocket)
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

            // Handle client in separate thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(socket: clientSocket)
            }
        }
    }

    private func handleClient(socket clientSocket: Int32) {
        defer { close(clientSocket) }

        // Read request length (4 bytes, big endian)
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let lengthRead = recv(clientSocket, &lengthBytes, 4, 0)
        guard lengthRead == 4 else {
            NSLog("Failed to read request length")
            return
        }

        let requestLength = Int(UInt32(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))
        guard requestLength > 0 && requestLength < 1_000_000 else {
            NSLog("Invalid request length: \(requestLength)")
            return
        }

        // Read request data
        var requestData = Data(count: requestLength)
        let dataRead = requestData.withUnsafeMutableBytes { ptr in
            recv(clientSocket, ptr.baseAddress!, requestLength, 0)
        }
        guard dataRead == requestLength else {
            NSLog("Failed to read request data")
            return
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
    }

    private func sendResponse(to socket: Int32, response: NotificationResponse) {
        let encoder = JSONEncoder()
        guard let responseData = try? encoder.encode(response) else {
            NSLog("Failed to encode response")
            return
        }

        // Send length prefix
        var length = UInt32(responseData.count).bigEndian
        _ = withUnsafeBytes(of: &length) { ptr in
            send(socket, ptr.baseAddress!, 4, 0)
        }

        // Send response data
        _ = responseData.withUnsafeBytes { ptr in
            send(socket, ptr.baseAddress!, responseData.count, 0)
        }
    }
}
