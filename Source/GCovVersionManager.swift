//
//  Copyright (c) 2015 Google Inc. All rights reserved.

import Foundation

public extension GCovVersionManager {

    class func collectVersionsInFolder(folderPath:NSString) -> NSMutableDictionary {
        let returnDict = NSMutableDictionary()
        let fileManager = NSFileManager()
        println("folderPath: \(folderPath)")

        if let enumerator = fileManager.enumeratorAtPath(folderPath as String) {
            let allFiles = enumerator.allObjects
            let gcovPaths = allFiles
                .filter { $0.hasPrefix("gcov") }
                .filter { fileManager.isExecutableFileAtPath(folderPath.stringByAppendingPathComponent($0 as! String)) }
                .map { folderPath.stringByAppendingPathComponent($0 as! String) }

            for gcovPath in gcovPaths {
                let name = gcovPath.lastPathComponent
                var version = ""

                if name != "gcov" {
                    if (name[advance(name.startIndex, 4)] == "-") {
                        version = name[advance(name.startIndex, 5)..<name.endIndex]
                    } else {
                        println("gcov binary name in odd format: \(gcovPath)")
                    }
                }

                returnDict[version] = gcovPath
            }
        }
        
        return returnDict;
    }

}
