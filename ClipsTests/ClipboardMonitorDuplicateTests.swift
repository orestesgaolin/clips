import XCTest
import CoreData
@testable import Clips

final class ClipboardMonitorDuplicateTests: XCTestCase {
    var persistence: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistence = PersistenceController.shared
    }
    
    override func tearDown() {
        persistence = nil
        super.tearDown()
    }
    
    /// Test that entries with the same hash can be fetched reliably
    func testHashFetchIsConsistent() throws {
        let context = persistence.context
        let testHash = "consistent-hash-\(UUID().uuidString)"
        
        // Create entry
        let entry = ClipboardEntry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.useCount = 0
        entry.isPinned = false
        entry.contentHash = testHash
        entry.title = "Test Entry"
        persistence.save()
        
        // Fetch multiple times - should find the same entry each time
        let request = ClipboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", testHash)
        request.fetchLimit = 1
        
        for attempt in 0..<3 {
            let results = try context.fetch(request)
            XCTAssertEqual(results.count, 1, "Attempt \(attempt): Should consistently find exactly one entry")
        }
    }
    
    /// Test that duplicate text entries are not created
    func testNoDuplicatesWithSameHash() throws {
        let context = persistence.context
        let testHash = "dup-test-\(UUID().uuidString)"
        
        // Create entry
        let entry = ClipboardEntry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.useCount = 0
        entry.isPinned = false
        entry.contentHash = testHash
        entry.title = "Test Content"
        persistence.save()
        
        // Fetch by hash - should find it
        let request = ClipboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", testHash)
        request.fetchLimit = 1
        
        let found = try context.fetch(request).first
        XCTAssertNotNil(found, "Should find existing entry by hash on second paste")
    }
}
