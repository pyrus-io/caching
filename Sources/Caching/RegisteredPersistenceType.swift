import Foundation

internal protocol AnyRegisteredPersistenceType {
    var typeIdentifier: String { get }
    func save(cacheManager: CacheManager) throws
    func restore(cacheManager: CacheManager) throws
    func deletePersistentStorage(cacheManager: CacheManager) throws
}

internal struct RegisteredPersistenceType<C: Cachable>: AnyRegisteredPersistenceType {
    
    var typeIdentifier: String { C.typeIdentifier }
    
    func save(cacheManager: CacheManager) throws {
        try cacheManager.save(dataOfType: C.self)
    }
    
    func restore(cacheManager: CacheManager) throws {
        try cacheManager.restoreCache(ofType: C.self)
    }
    
    func deletePersistentStorage(cacheManager: CacheManager) throws {
        try cacheManager.deletePersistentStorage(ofType: C.self)
    }
}
