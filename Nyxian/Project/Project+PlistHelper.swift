//
//  Project+PlistHelper.swift
//  LindDE
//
//  Created by fridakitten on 08.05.25.
//

import Foundation

class PlistHelper {
    /*
     Holds the values that are needed for the core functionality of the plist helper
     */
    var plistPath: String
    var savedModificationDate: Date
    var lastModificationDate: Date {
        get {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: plistPath) else { return Date() }
            guard let modDate = attributes[.modificationDate] as? Date else { return Date() }
            return modDate
        }
    }
    
    /*
     Holds the last dictionary
     */
    var dictionary: NSMutableDictionary?
    
    init(plistPath: String) {
        self.plistPath = plistPath
        self.savedModificationDate = Date()
        self.savedModificationDate = self.lastModificationDate
        self.reloadData()
    }
    
    /*
     In case that it has been changed not by project settings it gonna be reloaded if the saved modification date is older than the current modification date!
     */
    @discardableResult func reloadIfNeeded() -> Bool {
        let modDate = self.lastModificationDate
        let needsReload: Bool = self.savedModificationDate < modDate
        if needsReload {
            dictionary = NSMutableDictionary(contentsOfFile: plistPath)
            self.savedModificationDate = modDate
        }
        return needsReload
    }
    
    func reloadData() {
        dictionary = NSMutableDictionary(contentsOfFile: plistPath)
        self.savedModificationDate = self.lastModificationDate
    }
    
    /*
     Functions for the project settings
     */
    func writeKey(key: String, value: Any) {
        dictionary?[key] = value
        dictionary?.write(to: URL(fileURLWithPath: plistPath), atomically: true)
        self.savedModificationDate = Date()
    }
    
    func readKey(key: String) -> Any? {
        return dictionary?[key]
    }
    
    func readKeySecure<T: Decodable>(key: String, defaultValue: T) -> T {
        guard let value = dictionary?[key] as? T else {
            return defaultValue
        }
        return value
    }
}
