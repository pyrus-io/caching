import XCTest
@testable import Caching

final class CachingTests: XCTestCase {
    
    var storageDirectory: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last! }
    lazy var persistentStorage: PersistentStorageManager = .init(directoryUrl: storageDirectory)
    lazy var cacheManager: CacheManager = CacheManager(persistentStorage: persistentStorage)
    
    override func setUp() {
        super.setUp()
        cacheManager.registerTypeForPersistence(TestStruct.self)
        cacheManager.registerTypeForPersistence(TestChildStruct.self)
        cacheManager.registerTypeForPersistence(TestSubChildStruct.self)
    }

    func testCaching() throws {
        
        var changeCounts = 0
        cacheManager.changeBlock = { _, _ in
            changeCounts += 1
        }
        
        let fullStruct = TestStruct(cacheId: "abc", name: "Hello world", child: .init(cacheId: "xyz", value: 100, subChild: [.init(cacheId: "blahtest", value: "test")]))
        cacheManager.cache(fullStruct) // 3 changes

        let child = cacheManager.get(type: TestChildStruct.self, withId: "xyz", staleDate: nil)
        XCTAssertNotNil(child)

        let changedStruct = TestChildStruct(cacheId: "xyz", value: 99, subChild: [.init(cacheId: "haha", value: "booyah")])
        cacheManager.cache(changedStruct) // 2 changes

        let changedSubChild: [TestSubChildStruct] = [.init(cacheId: "haha", value: "killer"), .init(cacheId: "coolnew", value: "weird")]
        cacheManager.cache(changedSubChild) // 2 changes

        var fullStructRecovered = cacheManager.get(type: TestStruct.self, withId: "abc", staleDate: nil)
        fullStructRecovered?.establishConsistency(with: cacheManager, staleDate: nil)
        XCTAssertEqual(fullStructRecovered?.child.value, 99)
        
        XCTAssertEqual(changeCounts, 7)
        
        try! cacheManager.save()
        cacheManager.reset()
        try! cacheManager.restoreCache()

        fullStructRecovered = cacheManager.get(type: TestStruct.self, withId: "abc", staleDate: nil)
        fullStructRecovered?.establishConsistency(with: cacheManager, staleDate: nil)
        XCTAssertEqual(fullStructRecovered?.child.value, 99)
    }
    
    func testCacheExpiry() {
        
        // Given
        cacheManager.dateProvider = { Date(timeInterval: -1000, since: Date()) }
        cacheManager.cache(TestSubChildStruct(cacheId: "oldy1", value: "test"))
        cacheManager.cache(TestSubChildStruct(cacheId: "oldy2", value: "test"))
        
        cacheManager.dateProvider = { Date(timeInterval: -500, since: Date()) }
        cacheManager.cache(TestSubChildStruct(cacheId: "newer1", value: "test"))
        
        // When
        cacheManager.flushRecords(storedBefore: Date(timeInterval: -750, since: Date()))
        
        // Expect
        XCTAssertNil(cacheManager.get(type: TestSubChildStruct.self, withId: "oldy1", staleDate: nil))
        XCTAssertNil(cacheManager.get(type: TestSubChildStruct.self, withId: "oldy2", staleDate: nil))
        XCTAssertNotNil(cacheManager.get(type: TestSubChildStruct.self, withId: "newer1", staleDate: nil))
    }
    
    func testStaleExpiry() {
        let now = Date()
        
        // Given
        cacheManager.dateProvider = { Date(timeInterval: -1000, since: now) }
        cacheManager.cache(TestSubChildStruct(cacheId: "oldy1", value: "test"))
        cacheManager.cache(TestSubChildStruct(cacheId: "oldy2", value: "test"))
        cacheManager.cache(TestSubChildStruct(cacheId: "oldy3", value: "test"))
        
        XCTAssertNil(cacheManager.get(type: TestSubChildStruct.self, withId: "oldy1", staleDate: Date()))
        XCTAssertNotNil(cacheManager.get(type: TestSubChildStruct.self, withId: "oldy2", staleDate: Date(timeInterval: -1001, since: now)))
        XCTAssertNil(cacheManager.get(type: TestSubChildStruct.self, withId: "oldy3", staleDate: Date(timeInterval: -1000, since: now)))
    }
    
    func testAndMeasureWritingThreadSafety() {
        measure {
            let item = TestChildStruct(cacheId: "tester", value: 0, subChild: [])
            cacheManager.cache(item)
            DispatchQueue.concurrentPerform(iterations: 100_000) {_ in
                cacheManager.modify(type: TestChildStruct.self, withId: "tester") { (item) in
                    item?.value += 1
                }
            }
            let finalItem = cacheManager.get(type: TestChildStruct.self, withId: "tester", staleDate: nil)
            XCTAssertEqual(finalItem?.value, 100_000)
        }
    }
    
    func testAndMeasureReadingThreadSafety() {
        measure {
            let item = TestChildStruct(cacheId: "tester", value: 0, subChild: [])
            cacheManager.cache(item)
            DispatchQueue.concurrentPerform(iterations: 1_000_000) {_ in
                _ = cacheManager.get(type: TestChildStruct.self, withId: "tester", staleDate: nil)
            }
            XCTAssertEqual(item.value, 0)
        }
    }

}
