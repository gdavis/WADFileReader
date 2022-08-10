import Foundation
import SwiftyBytes

/* References:
 WAD file reader in C#, updated for League.
 https://github.com/LoL-Fantome/LeagueToolkit/blob/master/LeagueToolkit/IO/WadFile/Wad.cs
 */

/// Reads files to create `WADFile` objects.
public struct WADFileReader {
    public func read(fileAt url: URL) throws -> WADFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Error.fileDoesNotExist
        }

        let data = try Data(contentsOf: url)
        let header = try WADFile.Header(data: data)

        return WADFile(header: header)
    }
}

extension WADFileReader {
    public enum Error: Swift.Error {
        case incompleteImplementation
        case fileDoesNotExist
        case invalidFile
        case unsupportedVersion
    }
}


/// Defines the structure of a WAD file.
public struct WADFile {
    let header: Header
}


extension WADFile {
    /// Defines the contents of the header of a WAD file, updated for Riot Games.
    ///
    /// the magic header uses the following format:
    ///     RW{major version}{minor version}
    public struct Header {
        static let size: Int = 272
        static let prefix: String = "RW"

        public let major: UInt8
        public let minor: UInt8
        public let fileSignature: [UInt8]
        public let checksum: Int64

        public let numberOfEntries: UInt32
        public let entries: [WADFile.Entry]

        init(data: Data) throws {
            guard data.count > Header.size else {
                throw WADFileReader.Error.invalidFile
            }

            let binaryData = BinaryData(data: data)
            let reader: BinaryReader = BinaryReader(binaryData)
            let signature: FileSignature = try reader.read(2)

            guard try signature.prefix() == Header.prefix else {
                throw WADFileReader.Error.invalidFile
            }

            self.major = try reader.readUInt8()
            self.minor = try reader.readUInt8()

            guard major == 3 else {
                throw WADFileReader.Error.unsupportedVersion
            }

            self.fileSignature = try reader.read(256)
            self.checksum = try reader.readInt64()
            self.numberOfEntries = try reader.readUInt32()

            var entries = [WADFile.Entry]()
            for _ in 0..<numberOfEntries {
                let entry = try WADFile.Entry(reader: reader,
                                              majorVersion: major,
                                              minorVersion: minor)
                entries.append(entry)
            }
            self.entries = entries
        }
    }
}


// MARK: - File Signature

extension WADFile {
    typealias FileSignature = [UInt8]
}

extension WADFile.FileSignature {
    func prefix() throws -> String {
        guard count >= 2 else {
            throw WADFileReader.Error.invalidFile
        }

        var chars: [UInt8] = Array(self[0..<2])
        let data = Data(bytes: &chars, count: chars.count)
        guard let prefix = String(data: data, encoding: .ascii) else {
            throw WADFileReader.Error.invalidFile
        }

        return prefix
    }

    func majorVersion() throws -> UInt8 {
        guard count > 2 else {
            throw WADFileReader.Error.invalidFile
        }
        return self[2]
    }

    func minorVersion() throws -> UInt8 {
        guard count > 3 else {
            throw WADFileReader.Error.invalidFile
        }
        return self[3]
    }
}


// MARK: - Entry

extension WADFile {

    public struct Entry {
        public let hash: UInt64
        public let dataOffset: UInt32
        public let compressedSize: UInt32
        public let uncompressedSize: UInt32
        public let entryType: EntryType
        public let isDuplicated: Bool
        public let firstSubChunkIndex: UInt16
        public let checksum: [UInt8]
        public let checksumType: ChecksumType
        public let fileRedirection: String?

        init(reader: BinaryReader, majorVersion: UInt8, minorVersion: UInt8) throws {
            self.hash = try reader.readUInt64()
            self.dataOffset = try reader.readUInt32()
            self.compressedSize = try reader.readUInt32()
            self.uncompressedSize = try reader.readUInt32()

            let type: UInt8 = try reader.readUInt8()
            guard let entryType = EntryType(rawValue: type) else {
                throw WADFileReader.Error.invalidFile
            }
            self.entryType = entryType
            self.isDuplicated = try reader.readBool()
            self.firstSubChunkIndex = try reader.readUInt16()
            self.checksum = try reader.read(8)
            self.checksumType = .XXHash3

            if entryType == .fileRedirection {
                let currentPosition = reader.readIndex
                reader.jmp(Int(dataOffset))

                let redirectSize = try reader.readInt32()
                let redirectData = Data(try reader.read(Int(redirectSize)))
                let redirectString = String(data: redirectData, encoding: .ascii)
                self.fileRedirection = redirectString

                reader.jmp(Int(currentPosition))
            } else {
                self.fileRedirection = nil
            }
        }
    }

    public enum EntryType: UInt8 {
        case uncompressed
        case gzipCompressed
        case fileRedirection
        case zStandardCompressed
        case zStandardChunked
    }

    public enum ChecksumType {
        case SHA256, XXHash3
    }
}
