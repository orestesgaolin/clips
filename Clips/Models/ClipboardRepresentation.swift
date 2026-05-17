import CoreData

@objc(ClipboardRepresentation)
public class ClipboardRepresentation: NSManagedObject {
    @NSManaged public var typeIdentifier: String
    @NSManaged public var data: Data
    @NSManaged public var entry: ClipboardEntry?
}

extension ClipboardRepresentation {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardRepresentation> {
        NSFetchRequest<ClipboardRepresentation>(entityName: "ClipboardRepresentation")
    }
}
