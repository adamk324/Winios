import XCTest
@testable import Winios

final class WiniosTests: XCTestCase {
    func testPerformanceProfilesAreStableAndComplete() {
        XCTAssertEqual(Set(PerformanceProfile.allCases.map(\.rawValue)), Set(["Low-End", "Balanced", "Performance"]))
    }

    func testImportedApplicationEncodesAndDecodes() throws {
        let item = ImportedApplication(id: UUID(), name: "Setup", filename: "setup.exe", relativePath: "abc-setup.exe", importedAt: Date(timeIntervalSince1970: 10))
        let decoded = try JSONDecoder().decode(ImportedApplication.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(decoded, item)
    }

    func testPEHeaderOffsetIsReadFromDOSHeaderAndBoundsChecked() throws {
        var dosHeader = Data(repeating: 0, count: 64)
        dosHeader[0] = 0x4d
        dosHeader[1] = 0x5a
        dosHeader[0x3c] = 0x40

        XCTAssertEqual(try PEFileInspector.peHeaderOffset(in: dosHeader, fileSize: 70), 64)
        XCTAssertThrowsError(try PEFileInspector.peHeaderOffset(in: dosHeader, fileSize: 69))
    }

    func testPEMachineTypesAreReportedWithoutExecution() throws {
        let peHeader = Data([0x50, 0x45, 0x00, 0x00, 0x64, 0x86])
        XCTAssertEqual(try PEFileInspector.architecture(inPEHeader: peHeader), "x64")
        XCTAssertEqual(PEArchitecture.label(forMachine: 0xaa64), "ARM64")
        XCTAssertEqual(PEArchitecture.label(forMachine: 0xa641), "ARM64EC")
    }

    func testPEHeaderRejectsInvalidSignature() {
        XCTAssertThrowsError(try PEFileInspector.architecture(inPEHeader: Data([0, 0, 0, 0, 0x4c, 0x01])))
    }
}
