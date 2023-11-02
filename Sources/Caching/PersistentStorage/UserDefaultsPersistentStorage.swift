//
//  UserDefaultsPersistentStorage.swift
//
//  Created by K N on 2023-10-31.
//

import Foundation
import Caching

public final class UserDefaultsPersistentStorage: PersistentStorageManagingService {
    public init() {
        
    }
    
    public func store(data: Data, withName name: String) {
        UserDefaults.standard.setValue(data, forKey: name)
    }
    
    public func retrieve(dataNamed name: String) -> Data? {
        UserDefaults.standard.data(forKey: name)
    }
    
    public func delete(dataNamed name: String) throws {
        UserDefaults.standard.removeObject(forKey: name)
    }
}
