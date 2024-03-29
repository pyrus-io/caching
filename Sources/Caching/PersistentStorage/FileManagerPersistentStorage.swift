//
//  FileManagerPersistentStorage.swift
//
//  Created by K N on 2023-10-31.
//

import Foundation

public final class FileManagerPersistentStorage: PersistentStorageManagingService {
    
    public let directoryUrl: URL
    
    public init(directoryUrl: URL) {
        self.directoryUrl = directoryUrl
    }
    
    public func store(data: Data, withName name: String) {
        let result = FileManager.default.createFile(atPath: fullStoragePath(forName: name), contents: data, attributes: [:])
        if !result {
            fatalError("Couldn't create file")
        }
    }
    
    public func retrieve(dataNamed name: String) -> Data? {
        return FileManager.default.contents(atPath: fullStoragePath(forName: name))
    }
    
    public func delete(dataNamed name: String) throws {
        try FileManager.default.removeItem(atPath: fullStoragePath(forName: name))
    }
    
    private func fullStoragePath(forName name: String) -> String {
        return "\(directoryUrl.path)/\(name).dat"
    }
}
