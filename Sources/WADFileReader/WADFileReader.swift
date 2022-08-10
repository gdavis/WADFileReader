import Foundation

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

//        let data = try Data(contentsOf: url)
//        let header = try WADFile.Header(data: data)

        let handle = try FileHandle(forReadingFrom: url)
        let header = try WADFile.Header(fileHandle: handle)

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

        public let numberOfDirectories: UInt32
        public let directoryOffset: UInt32
        public let major: UInt8
        public let minor: UInt8

        init(fileHandle: FileHandle) throws {
            let bytes = fileHandle
                .readData(ofLength: Header.size)
                .map { $0 }

            try self.init(signature: bytes)
        }

        init(data: Data) throws {
            guard data.count > Header.size else {
                throw WADFileReader.Error.invalidFile
            }
            let identifyBuffer: FileSignature = data[0..<4].map { $0 }
            try self.init(signature: identifyBuffer)
        }

        init(signature: FileSignature) throws {
            guard try signature.prefix() == Header.prefix else {
                throw WADFileReader.Error.invalidFile
            }

            var iterator = signature
                .dropFirst(2)
                .makeIterator()

//            let majorVersion = try signature.majorVersion()
            guard let majorVersion: UInt8 = iterator.next(),
                  let minorVersion: UInt8 = iterator.next()
            else {
                throw WADFileReader.Error.invalidFile
            }

            guard majorVersion == 3 else {
                throw WADFileReader.Error.unsupportedVersion
            }

            let numDirectories = signature[4..<8].withUnsafeBytes { pointer in
                pointer.load(as: UInt32.self)
            }
            let directoryOffset = signature[8..<12].withUnsafeBytes { pointer in
                pointer.load(as: UInt32.self)
            }

            self.init(numberOfDirectories: numDirectories,
                      directoryOffset: directoryOffset,
                      major: majorVersion,
                      minor: minorVersion
            )
        }

        internal init(numberOfDirectories: UInt32, directoryOffset: UInt32, major: UInt8, minor: UInt8) {
            self.numberOfDirectories = numberOfDirectories
            self.directoryOffset = directoryOffset
            self.major = major
            self.minor = minor
        }
    }
}


// MARK: - File Signature

extension WADFile {
    typealias FileSignature = [UInt8]
}

extension WADFile.FileSignature {
    func prefix() throws -> String {
        guard count > 2 else {
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
