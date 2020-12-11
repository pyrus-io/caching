import Foundation

public protocol Cachable: Codable {
    var cacheId: String { get }
    func cacheChildren(in cacheService: CacheManagingService)
    mutating func establishConsistency(with cacheService: CacheManagingService, staleDate: Date?)
}

extension Cachable {
    
    public static var typeIdentifier: String { String(describing: Self.self) }
    
    public func cacheChildren(in cacheService: CacheManagingService) { }
    
    public mutating func establishConsistency(with cacheService: CacheManagingService, staleDate: Date?) {
        guard let latest = cacheService.get(type: Self.self, withId: cacheId, staleDate: staleDate) else {
            return
        }
        self = latest
    }
}
