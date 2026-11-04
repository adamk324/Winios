import Foundation

enum PEArchitecture {
    static func label(forMachine machine: UInt16) -> String {
        switch machine {
        case 0x014c: return "x86"
        case 0x8664: return "x64"
        case 0xaa64: return "ARM64"
        case 0xa641: return "ARM64EC"
        case 0xa64e: return "ARM64X"
        case 0x01c4: return "ARMNT"
        default: return String(format: "Unknown (0x%04X)", machine)
        }
    }
}

enum PEFileInspector {
    enum InspectionError: Error {
        case truncatedDOSHeader
        case invalidDOSSignature
        case invalidPEOffset
        case truncatedPEHeader
        case invalidPESignature
    }

    /// Reads only the fixed DOS header and PE/COFF header; it never maps or executes the file.
    static func architecture(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let fileSize = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        let dosHeader = handle.readData(ofLength: 64)
        let headerOffset = try peHeaderOffset(in: dosHeader, fileSize: fileSize)
        try handle.seek(toOffset: headerOffset)
        let peHeader = handle.readData(ofLength: 6)
        return try architecture(inPEHeader: peHeader)
    }

    static func peHeaderOffset(in dosHeader: Data, fileSize: UInt64) throws -> UInt64 {
        let bytes = [UInt8](dosHeader)
        guard bytes.count >= 64 else { throw InspectionError.truncatedDOSHeader }
        guard bytes[0] == 0x4d, bytes[1] == 0x5a else { throw InspectionError.invalidDOSSignature }

        let offset = UInt64(readUInt32LE(bytes, at: 0x3c))
        guard offset <= fileSize, fileSize - offset >= 6 else { throw InspectionError.invalidPEOffset }
        return offset
    }

    static func architecture(inPEHeader header: Data) throws -> String {
        let bytes = [UInt8](header)
        guard bytes.count >= 6 else { throw InspectionError.truncatedPEHeader }
        guard bytes[0] == 0x50, bytes[1] == 0x45, bytes[2] == 0, bytes[3] == 0 else {
            throw InspectionError.invalidPESignature
        }
        let machine = UInt16(bytes[4]) | (UInt16(bytes[5]) << 8)
        return PEArchitecture.label(forMachine: machine)
    }

    private static func readUInt32LE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}
