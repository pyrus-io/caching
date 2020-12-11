//
//  TestStructures.swift
//  
//
//  Created by Kyle Newsome on 2020-11-03.
//

import Foundation
import Caching

struct TestStruct: Cachable {
    var cacheId: String
    var name: String
    var child: TestChildStruct
    
    func cacheChildren(in cacheService: CacheManagingService) {
        cacheService.cache(child)
    }
    
    mutating func establishConsistency(with cacheService: CacheManagingService, staleDate: Date?) {
        guard let latest = cacheService.get(type: Self.self, withId: cacheId, staleDate: staleDate) else {
            return
        }
        self = latest
        child.establishConsistency(with: cacheService, staleDate: staleDate)
    }
}

struct TestChildStruct: Cachable {
    var cacheId: String
    var value: Int
    var subChild: [TestSubChildStruct]
    
    func cacheChildren(in cacheService: CacheManagingService) {
        cacheService.cache(subChild)
    }
    
    mutating func establishConsistency(with cacheService: CacheManagingService, staleDate: Date?) {
        guard let latest = cacheService.get(type: Self.self, withId: cacheId, staleDate: staleDate) else {
            return
        }
        self = latest
        subChild = subChild.map { val in
            var new = val
            new.establishConsistency(with: cacheService, staleDate: staleDate)
            return new
        }
    }
}

struct TestSubChildStruct: Cachable {
    var cacheId: String
    var value: String
}
