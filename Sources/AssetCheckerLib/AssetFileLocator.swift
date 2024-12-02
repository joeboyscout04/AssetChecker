import Foundation

public struct AssetFileLocator {
    
   public struct Results {
       public let unusedAssets: [AssetAndCatalog]
       public let brokenAssets: [String: [String]]
    }
    
    public struct AssetAndCatalog: Equatable {
        public let asset: String
        public let catalog: String
    }
    
    public init(sourcePath: String,
         catalog: String?,
         ignoredUnusedNames: [String],
         ignoreFile: String?,
         swiftgenPrefixes: [String],
         fileManager: FileManager = .default) {
        self.sourcePath = sourcePath
        self.swiftgenPrefixes = swiftgenPrefixes
        self.assetCatalogPaths = {
            if let providedCatalog = catalog {
                return [providedCatalog]
            } else {
                // detect automatically
                return fileManager.enumerator(atPath: sourcePath)?.elementsInEnumerator().filter { $0.hasSuffix(".xcassets") } ?? []
            }
        }()
        
        self.ignoredUnusedNames = {
            let ignoreFilePath = ignoreFile ?? "\(fileManager.currentDirectoryPath)/.assetcheckerignore"
            guard let data = fileManager.contents(atPath: ignoreFilePath),
                  let fileContent = String(data: data, encoding: .utf8) else { return ignoredUnusedNames }
            return fileContent.components(separatedBy: .newlines)
        }()
        
        self.fileManager = fileManager
    }
    
    private let fileManager: FileManager
    let sourcePath: String
    public let assetCatalogPaths: [String]
    let ignoredUnusedNames: [String]
    private let swiftgenPrefixes: [String]
    
    public func checkAssets() -> Results {
        
        let availableAssets = catalogAssets(assetCatalogPaths)
        let availableAssetNames = Set(availableAssets.map{$0.asset} )
        let usedAssets = usedAssets()
        let usedAssetNames = Set(usedAssets.keys + ignoredUnusedNames)

        // Generate Warnings for Unused Assets
        let unused = availableAssets.filter { assetAndCatalog -> Bool in
            
            let isUsed = usedAssetNames.contains { name in
                name.isAlphanumericMatch(with: assetAndCatalog.asset)
            }
            
            return !isUsed && !isIgnored(assetAndCatalog.asset)
        }
        
        let broken = usedAssets.filter { (assetName, references) -> Bool in
            
            let isAvailable = availableAssetNames.contains { name in
                name.isAlphanumericMatch(with: assetName)
            }
            return !isAvailable && !isIgnored(assetName)
        }
        
        return Results(unusedAssets: unused, brokenAssets: broken)
    }
    
    /// List assets in found asset catalogs
    private func catalogAssets(_ paths: [String]) -> [AssetAndCatalog] {
        
        return paths.flatMap { (catalog) -> [AssetAndCatalog] in
            
            let extensionName = "imageset"
            let enumerator = fileManager.enumerator(atPath: catalog)
            return enumerator?.elementsInEnumerator()
                .filter { $0.hasSuffix(extensionName) }                             // Is Asset
                .map { $0.replacingOccurrences(of: ".\(extensionName)", with: "") } // Remove extension
                .map { $0.components(separatedBy: "/").last ?? $0 }                 // Remove folder path
                .map { AssetAndCatalog(asset: $0, catalog: catalog)} ?? []
        }
    }

    /// List Assets used in the codebase, with the asset name as the key
    private func usedAssets() -> [String: [String]]  {
        let enumerator = fileManager.enumerator(atPath: sourcePath)
        
        var assetUsageMap: [String: [String]] = [:]
        
        // Only Swift and Obj-C files
        let files = enumerator?.elementsInEnumerator()
            .filter { $0.hasSuffix(".m") || $0.hasSuffix(".swift") || $0.hasSuffix(".xib") || $0.hasSuffix(".storyboard") } ?? []
        
        /// Find sources of assets within the contents of a file
        func assetNames(in fileContents: String) -> [String] {
            var assetStringReferences = [String]()
            let namePattern = "([\\w-]+)"
            var patterns = [
                "#imageLiteral\\(resourceName:\\s*\"\(namePattern)\"\\)",
                "(?<![a-zA-Z0-9])UIImage\\(named:\\s*\"\(namePattern)\"\\)",
                "(?<![a-zA-Z0-9])UIImage imageNamed:\\s*\\@\"\(namePattern)\"",
                "\\<image name=\"\(namePattern)\".*",
                "R\\.image\\.\(namePattern)\\(\\)",
                "(?<![a-zA-Z0-9])UIImage\\(resource:\\s*\\.\(namePattern)\\)",
                "(?<![a-zA-Z0-9])Image\\(\"\(namePattern)\"\\)",
                "(?<![a-zA-Z0-9])Image\\(uiImage:\\s*\\.\(namePattern)\\)"
            ]
            for prefix in swiftgenPrefixes {
                let swiftgenPattern = "(?<![a-zA-Z0-9])\(prefix)\\.\(namePattern)\\.image"
                patterns.append(swiftgenPattern)
            }
            for p in patterns {
                let regex = try? NSRegularExpression(pattern: p, options: [])
                let range = NSRange(location: 0, length: (fileContents as NSString).length)
                regex?.enumerateMatches(in: fileContents, options: [], range: range) { result, _, _ in
                    if let r = result {
                        let value = (fileContents as NSString).substring(with: r.range(at: 1))
                        assetStringReferences.append(value)
                    }
                }
            }
            return assetStringReferences
        }
        
        for filename in files {
            // Build file paths
            let filepath = "\(sourcePath)/\(filename)"
            
            // Get file contents
            if let fileData = fileManager.contents(atPath: filepath),
            let fileContents = String(data: fileData, encoding: .utf8) {
                // Find occurrences of asset names
                let references = assetNames(in: fileContents)
                
                // assemble the map
                for asset in references {
                    let updatedReferences = assetUsageMap[asset] ?? []
                    assetUsageMap[asset] = updatedReferences + [filepath]
                }
            }
        }
        
        return assetUsageMap
    }
    
    /// If the asset should be ignored
    private func isIgnored(_ assetName: String) -> Bool {
        let ignoreCount = ignoredUnusedNames.reduce(0) { (sum, ignore) -> Int in
            let ignoreRegex = try? NSRegularExpression(pattern: ignore, options: [])
            return sum + (ignoreRegex?.numberOfMatches(in: assetName, options: [], range: NSRange(location: 0, length: assetName.count)) ?? 0)
        }
        return ignoreCount > 0
    }
}

