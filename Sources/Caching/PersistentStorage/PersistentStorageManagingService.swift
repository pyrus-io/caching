import Foundation

public protocol PersistentStorageManagingService {
    func store(data: Data, withName name: String)
    func retrieve(dataNamed name: String) -> Data?
    func delete(dataNamed name: String) throws
}
