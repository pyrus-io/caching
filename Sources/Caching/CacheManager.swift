import Foundation

public typealias CachableTypeIdentifier = String
public typealias CachableId = String

public protocol CacheManagingService {
    
    func get<C: Cachable>(type: C.Type, withId id: String, staleDate: Date?) -> C?
    func getCacheRecord<C: Cachable>(type: C.Type, withId id: String) -> CacheRecord<C>?
    
    func cache<C: Cachable>(_ item: C)
    func cache<C: Cachable>(_ items: [C])
    func cache<C: Cachable>(_ item: C, withExplicitId id: String)
    
    func modify<C>(type: C.Type, withId id: String, modify: (inout C?) -> Void) where C : Cachable
    
    func flushRecords(storedBefore staleDate: Date)
    func expire<C: Cachable>(type: C.Type, withId id: String)
    
    func registerTypeForPersistence<C>(_ type: C.Type) where C : Cachable
    func save() throws
    func restoreCache() throws
    func clearCache() throws
}

public enum CacheManagerError: Error {
    case cacheClearing([Error])
}

public typealias DateProviderBlock = () -> Date
public typealias ChangeBlock = (CachableTypeIdentifier, Cachable) -> Void

public final class CacheManager: CacheManagingService {
    
    private let mutex = DispatchQueue(label: "io.pyrus.caching.SynchronizedBarrier", attributes: .concurrent)
    
    private var cache: [CachableTypeIdentifier: [CachableId: AnyCacheRecord]] = [:]
    
    public var dateProvider: DateProviderBlock
    public var changeBlock: ChangeBlock?
    
    private var registeredPersistentTypes: [AnyRegisteredPersistenceType] = []
    var persistentStorage: PersistentStorageManagingService
    
    public init(
        persistentStorage: PersistentStorageManagingService,
        dateProvider: DateProviderBlock? = nil,
        changeBlock: ChangeBlock? = nil
    ) {
        self.persistentStorage = persistentStorage
        self.dateProvider = dateProvider ?? { Date() }
        self.changeBlock = changeBlock
    }
    
    public func reset() {
        cache = [:]
    }
    
    // MARK: - Reading
    
    public func get<C>(type: C.Type, withId id: String, staleDate: Date?) -> C? where C : Cachable {
        return mutex.sync {
            if let record = self.cache[C.typeIdentifier]?[id] as? CacheRecord<C> {
                if record.isValid(staleDate: staleDate) {
                    return record.value
                } else {
                    return nil
                }
            }
            return nil
        }
    }
    
    public func getCacheRecord<C>(type: C.Type, withId id: String) -> CacheRecord<C>? where C : Cachable {
        mutex.sync {
            self.cache[C.typeIdentifier]?[id] as? CacheRecord<C>
        }
    }
    
    // MARK: - Writing
    
    public func cache<C>(_ item: C) where C : Cachable {
        self.cache(item, withExplicitId: item.cacheId)
    }
    
    public func cache<C>(_ items: [C]) where C : Cachable {
        mutex.sync(flags: .barrier) {
            var cacheTypeDict = self.cache[C.typeIdentifier, default: [:]]
            for item in items {
                cacheTypeDict[item.cacheId] = CacheRecord(lastUpdated: self.dateProvider(), value: item)
                item.cacheChildren(in: self)
            }
            self.cache[C.typeIdentifier] = cacheTypeDict
        }
        items.forEach {
            changeBlock?(C.typeIdentifier, $0)
        }
    }
    
    public func cache<C>(_ item: C, withExplicitId id: String) where C : Cachable {
        mutex.sync(flags: .barrier) {
            cache[C.typeIdentifier, default: [:]][id] = CacheRecord(lastUpdated: dateProvider(), value: item)
        }
        changeBlock?(C.typeIdentifier, item)
        item.cacheChildren(in: self)
    }
    
    public func modify<C>(type: C.Type, withId id: String, modify: (inout C?) -> Void) where C : Cachable {
        var item: C?
        mutex.sync(flags: .barrier) {
            var record = cache[C.typeIdentifier, default: [:]][id] as? CacheRecord<C>
            item = record?.value
            modify(&item)
            record = item.map { CacheRecord(lastUpdated: dateProvider(), value: $0) }
            cache[C.typeIdentifier, default: [:]][id] = record
        }
        item?.cacheChildren(in: self)
        if let i = item {
            changeBlock?(C.typeIdentifier, i)
        }
    }
    
    // MARK: - Expiry Management
    public func flushRecords(storedBefore staleDate: Date) {
        mutex.sync(flags: .barrier) {
            var newCache: [CachableTypeIdentifier: [CachableId: AnyCacheRecord]] = .init()
            for typeDict in cache {
                var newTypeDict: [CachableId: AnyCacheRecord] = .init()
                for (key, value) in typeDict.value {
                    if value.lastUpdated > staleDate {
                        newTypeDict[key] = value
                    }
                }
                newCache[typeDict.key] = newTypeDict
            }
            cache = newCache
        }
    }
    
    public func clearCache() throws {
        mutex.sync(flags: .barrier) {
            cache = [:]
        }
        
        var errors: [Error] = []
        registeredPersistentTypes.forEach {
            do {
                try $0.deletePersistentStorage(cacheManager: self)
            } catch {
                errors.append(error)
            }
        }
        if errors.count > 0 {        
            throw CacheManagerError.cacheClearing(errors)
        }
    }
    
    public func expire<C: Cachable>(type: C.Type, withId id: String) {
        mutex.sync(flags: .barrier) {
            var newDict = cache[C.typeIdentifier]
            newDict?[id] = nil
            cache[C.typeIdentifier] = newDict
        }
    }
    
    // MARK: - Persistence
    
    public func registerTypeForPersistence<C>(_ type: C.Type) where C : Cachable {
        let registeredType = RegisteredPersistenceType<C>()
        registeredPersistentTypes.append(registeredType)
    }
    
    public func save() throws {
        try registeredPersistentTypes.forEach { try $0.save(cacheManager: self) }
    }
    
    public func restoreCache() throws {
        try registeredPersistentTypes.forEach { try $0.restore(cacheManager: self) }
    }
    
    internal func save<C>(dataOfType type: C.Type) throws where C : Cachable {
        guard let dataDict = cache[C.typeIdentifier] as? [CachableId: CacheRecord<C>] else { return }
        let data = try JSONEncoder().encode(dataDict)
        persistentStorage.store(data: data, withName: C.typeIdentifier)
    }
    
    internal func restoreCache<C>(ofType type: C.Type) throws where C : Cachable {
        guard let data = persistentStorage.retrieve(dataNamed: C.typeIdentifier) else {
            return
        }
        let dict = try JSONDecoder().decode([CachableId: CacheRecord<C>].self, from: data)
        cache[C.typeIdentifier] = dict
    }
    
    internal func deletePersistentStorage<C>(ofType type: C.Type) throws where C : Cachable {
        try persistentStorage.delete(dataNamed: C.typeIdentifier)
    }

}
