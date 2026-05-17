import CoreData

@objc(ClipboardEntry)
public class ClipboardEntry: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var useCount: Int32
    @NSManaged public var sourceAppBundleId: String?
    @NSManaged public var sourceAppName: String?
    @NSManaged public var isPinned: Bool
    @NSManaged public var title: String
    @NSManaged public var contentHash: String
    @NSManaged public var representations: NSSet
}

extension ClipboardEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardEntry> {
        NSFetchRequest<ClipboardEntry>(entityName: "ClipboardEntry")
    }

    @objc(addRepresentationsObject:)
    @NSManaged public func addToRepresentations(_ value: ClipboardRepresentation)

    @objc(removeRepresentationsObject:)
    @NSManaged public func removeFromRepresentations(_ value: ClipboardRepresentation)

    var representationSet: Set<ClipboardRepresentation> {
        representations as? Set<ClipboardRepresentation> ?? []
    }

    var plainText: String? {
        representationSet
            .first { $0.typeIdentifier == "public.utf8-plain-text" }
            .flatMap { String(data: $0.data, encoding: .utf8) }
    }
}
