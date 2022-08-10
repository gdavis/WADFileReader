import XCTest
@testable import WADFileReader

final class WADFileReaderTests: XCTestCase {

    func testReadFile() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource:"assets", withExtension: "wad")
        )
        let reader = WADFileReader()
        let file = try reader.read(fileAt: url)

        XCTAssertEqual(file.header.major, 3)
        XCTAssertEqual(file.header.minor, 3)
        XCTAssertEqual(file.header.numberOfEntries, 45)
    }

    func test_hasWADPrefix() throws {
        var bytes: [UInt8] = [0x52, 0x57, 0x03, 0x03]
        XCTAssertEqual(try bytes.prefix(), "RW")

        bytes = [0x47, 0x44, 0x03, 0x01]
        XCTAssertEqual(try bytes.prefix(), "GD")
    }

    func test_version() throws {
        var bytes: [UInt8] = [0x52, 0x57, 0x03, 0x03]
        XCTAssertEqual(try bytes.majorVersion(), 3)
        XCTAssertEqual(try bytes.minorVersion(), 3)

        bytes = [0x52, 0x57, 0x03, 0x01]
        XCTAssertEqual(try bytes.majorVersion(), 3)
        XCTAssertEqual(try bytes.minorVersion(), 1)
    }
}
