import AppKit
import XCTest
@testable import Clips

final class ClipboardMonitorDuplicateTests: XCTestCase {
    func testSameTextKeepsSameHashWhenMetadataChanges() {
        let firstItem = NSPasteboardItem()
        firstItem.setString("same text", forType: .string)
        firstItem.setData(Data("metadata-a".utf8), forType: NSPasteboard.PasteboardType("com.example.source"))

        let secondItem = NSPasteboardItem()
        secondItem.setString("same text", forType: .string)
        secondItem.setData(Data("metadata-b".utf8), forType: NSPasteboard.PasteboardType("com.example.source"))
        secondItem.setData(Data("metadata-c".utf8), forType: NSPasteboard.PasteboardType("com.example.timestamp"))

        let firstHash = ClipboardContentHasher.hash(
            item: firstItem,
            types: firstItem.types,
            representations: representations(for: firstItem)
        )
        let secondHash = ClipboardContentHasher.hash(
            item: secondItem,
            types: secondItem.types,
            representations: representations(for: secondItem)
        )

        XCTAssertEqual(firstHash, secondHash)
    }

    func testDifferentTextProducesDifferentHash() {
        let firstItem = NSPasteboardItem()
        firstItem.setString("first text", forType: .string)
        firstItem.setData(Data("metadata-a".utf8), forType: NSPasteboard.PasteboardType("com.example.source"))

        let secondItem = NSPasteboardItem()
        secondItem.setString("second text", forType: .string)
        secondItem.setData(Data("metadata-a".utf8), forType: NSPasteboard.PasteboardType("com.example.source"))

        let firstHash = ClipboardContentHasher.hash(
            item: firstItem,
            types: firstItem.types,
            representations: representations(for: firstItem)
        )
        let secondHash = ClipboardContentHasher.hash(
            item: secondItem,
            types: secondItem.types,
            representations: representations(for: secondItem)
        )

        XCTAssertNotEqual(firstHash, secondHash)
    }

    private func representations(for item: NSPasteboardItem) -> [(String, Data)] {
        item.types.compactMap { type in
            guard let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        }
    }
}
