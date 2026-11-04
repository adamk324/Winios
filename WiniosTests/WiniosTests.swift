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
}
