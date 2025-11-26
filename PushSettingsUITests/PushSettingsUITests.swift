import XCTest

final class PushSettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state such as interface orientation required for tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    
    func testToggleExistsAndCanBeToggled() throws {
        
        let app = XCUIApplication()
        app.launchArguments.append("UI_TESTING")
        app.launch()
        
        // 1. Find the toggle by its label text
        
        let toggle = app.switches["pushNotificationToggle"] //.element(matching: XCUIElement.ElementType.switch, identifier: "pushNotificationToggle") //app.switches["Enable push notifications"].firstMatch
        
        let currentOnString = toggle.value as? String
        let currentOn = currentOnString == "1"
        if currentOn != true {
            print("currentOn: ", currentOn)
            print("I am here ")
            toggle.tap()
        }
            
        
        
        // 2. Wait until the toggle appears
        let exists = toggle.waitForExistence(timeout: 5.0)
        XCTAssertTrue(exists, "The push notifications toggle should exist on screen")
        
        
        // 3. Wait until it is enabled (loading finished)
        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let enabledExpectation = expectation(
            for: enabledPredicate,
            evaluatedWith: toggle,
            handler: nil
        )
        wait(for: [enabledExpectation], timeout: 10.0)
        
        // 4. Capture initial value 0 or 1
        
        let initialValue = toggle.value as? String
        
        XCTAssertTrue(toggle.exists)
        XCTAssertTrue(toggle.isHittable)
        
        // 5. Tap the toggle
        toggle.tap()
        
        XCTAssertTrue(toggle.exists)
        XCTAssertTrue(toggle.isHittable)
        
        // 6. Wait for the value to change (registration flow completes)
        let valueChangedPredicate = NSPredicate(format: "value != %@", initialValue ?? "")
        let valueChangedExpectation = expectation(
            for: valueChangedPredicate,
            evaluatedWith: toggle,
            handler: nil
        )
        wait(for: [valueChangedExpectation], timeout: 10.0)
        
        let newValue = toggle.value as? String
        
        print("Toggle value was \(initialValue ?? "nil"), now \(newValue ?? "nil")")
        
        let predicate = NSPredicate(format: "value != %@", initialValue ?? "")
        let exp = expectation(for: predicate, evaluatedWith: toggle)
        wait(for: [exp], timeout: 5.0)
        
        XCTAssertNotEqual(initialValue, newValue, "Toggling should change the switch value")
        
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch the application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

