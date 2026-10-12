import XCTest
import ServiceManagement

private struct FakeError: LocalizedError {
    var errorDescription: String? { "Operation not permitted" }
}

private final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status
    /// The status `register()` moves to on success.
    var statusAfterRegister: SMAppService.Status = .enabled
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

final class LaunchAtLoginStateTests: XCTestCase {
    func testStatusMapping() {
        XCTAssertEqual(LaunchAtLoginState(.enabled), .on)
        XCTAssertEqual(LaunchAtLoginState(.requiresApproval), .requiresApproval)
        XCTAssertEqual(LaunchAtLoginState(.notRegistered), .off)
        XCTAssertEqual(LaunchAtLoginState(.notFound), .off)
    }

    func testIsOn() {
        XCTAssertTrue(LaunchAtLoginState.on.isOn)
        XCTAssertTrue(LaunchAtLoginState.requiresApproval.isOn)
        XCTAssertFalse(LaunchAtLoginState.off.isOn)
    }
}

final class LaunchAtLoginTests: XCTestCase {
    func testDefaultsOffWhenNotRegistered() {
        let model = LaunchAtLogin(service: FakeLoginItemService(status: .notRegistered))
        XCTAssertEqual(model.state, .off)
        XCTAssertNil(model.error)
    }

    func testReadsExistingSystemState() {
        let model = LaunchAtLogin(service: FakeLoginItemService(status: .enabled))
        XCTAssertEqual(model.state, .on)
    }

    func testEnableRegisters() {
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(service: service)
        model.setEnabled(true)
        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(model.state, .on)
        XCTAssertNil(model.error)
    }

    func testEnableNeedingApproval() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval
        let model = LaunchAtLogin(service: service)
        model.setEnabled(true)
        XCTAssertEqual(model.state, .requiresApproval)
    }

    func testDisableUnregisters() {
        let service = FakeLoginItemService(status: .enabled)
        let model = LaunchAtLogin(service: service)
        model.setEnabled(false)
        XCTAssertEqual(service.unregisterCalls, 1)
        XCTAssertEqual(model.state, .off)
    }

    func testDisableWithdrawsPendingApproval() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let model = LaunchAtLogin(service: service)
        model.setEnabled(false)
        XCTAssertEqual(service.unregisterCalls, 1)
        XCTAssertEqual(model.state, .off)
    }

    func testDisableWhenAlreadyOffSkipsUnregister() {
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(service: service)
        model.setEnabled(false)
        XCTAssertEqual(service.unregisterCalls, 0)
        XCTAssertNil(model.error)
    }

    func testRegisterFailureSurfacesErrorAndKeepsState() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeError()
        let model = LaunchAtLogin(service: service)
        model.setEnabled(true)
        XCTAssertEqual(model.state, .off)
        XCTAssertEqual(model.error, "Operation not permitted")
    }

    func testUnregisterFailureSurfacesError() {
        let service = FakeLoginItemService(status: .enabled)
        service.unregisterError = FakeError()
        let model = LaunchAtLogin(service: service)
        model.setEnabled(false)
        XCTAssertEqual(model.state, .on)
        XCTAssertEqual(model.error, "Operation not permitted")
    }

    func testSuccessClearsPreviousError() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeError()
        let model = LaunchAtLogin(service: service)
        model.setEnabled(true)
        service.registerError = nil
        model.setEnabled(true)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.state, .on)
    }

    func testRefreshPicksUpExternalChange() {
        let service = FakeLoginItemService(status: .enabled)
        let model = LaunchAtLogin(service: service)
        service.status = .notRegistered
        model.refresh()
        XCTAssertEqual(model.state, .off)
    }
}
