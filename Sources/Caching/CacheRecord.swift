import Foundation

public protocol AnyCacheRecord {
    var lastUpdated: Date { get }
    
    func isValid(staleDate: Date?) -> Bool
    func isFresh(freshExpiry: Date?) -> Bool
}

public extension AnyCacheRecord {
    func isFresh(freshExpiry: Date?) -> Bool {
        if let expiry = freshExpiry {
            return lastUpdated > expiry
        }
        return false
    }
    
    func isValid(staleDate: Date?) -> Bool {
        guard let staleTime = staleDate else { return true }
        if lastUpdated <= staleTime {
            return false
        } else {
            return true
        }
    }
}

public struct CacheRecord<C: Cachable>: Codable, AnyCacheRecord {
    public var lastUpdated: Date
    public var value: C
}
