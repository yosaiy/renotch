import Foundation

private let maximumMessageSize = 1_048_576
private let input = FileHandle.standardInput
private let output = FileHandle.standardOutput
private let errorOutput = FileHandle.standardError

while let header = readExactly(4, from: input) {
    let bytes = [UInt8](header)
    let messageLength = Int(bytes[0])
        | (Int(bytes[1]) << 8)
        | (Int(bytes[2]) << 16)
        | (Int(bytes[3]) << 24)

    guard messageLength > 0, messageLength <= maximumMessageSize,
          let payload = readExactly(messageLength, from: input),
          let payloadString = String(data: payload, encoding: .utf8) else {
        writeError("Invalid native messaging payload.\n")
        break
    }

    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.vincentyosi.virtualnotch.browser-activity"),
        object: nil,
        userInfo: ["payload": payloadString],
        deliverImmediately: true
    )
    writeMessage(Data("{\"ok\":true}".utf8))
}

private func readExactly(_ byteCount: Int, from handle: FileHandle) -> Data? {
    var result = Data()
    while result.count < byteCount {
        let chunk = handle.readData(ofLength: byteCount - result.count)
        if chunk.isEmpty { return nil }
        result.append(chunk)
    }
    return result
}

private func writeMessage(_ data: Data) {
    let length = UInt32(data.count)
    let header = Data([
        UInt8(length & 0xff),
        UInt8((length >> 8) & 0xff),
        UInt8((length >> 16) & 0xff),
        UInt8((length >> 24) & 0xff)
    ])
    output.write(header)
    output.write(data)
}

private func writeError(_ message: String) {
    errorOutput.write(Data(message.utf8))
}
