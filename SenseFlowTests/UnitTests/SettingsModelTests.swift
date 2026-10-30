//
//  SettingsModelTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-27.
//

import XCTest
import AppKit
@testable import SenseFlow

@MainActor
final class SettingsModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled)
        super.tearDown()
    }

    func test_init_whenTextSelectionFlagMissing_defaultsToDisabled() {
        XCTAssertNil(UserDefaults.standard.object(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled))

        let model = SettingsModel()

        XCTAssertFalse(model.textSelectionEnabled)
        XCTAssertNil(UserDefaults.standard.object(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled))
    }
}
