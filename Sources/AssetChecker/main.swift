import Foundation
import ArgumentParser

public struct AssetChecker: ParsableCommand {
    public init() {}
    
    public static var configuration = CommandConfiguration(
        abstract: "AssetChecker 👮‍♀️",
        version: "0.3.1")
    
    @Option(name: .long, help: "The path to the source code you want to check.")
    private var source: String = FileManager.default.currentDirectoryPath

    @Option(name: .long, help: "The asset catalog to check for extra assets.  Omitting this argument will search for asset catalogs.")
    private var catalog: String?
    
    @Option(name: .long, help: "Comma-separated asset names to ignore")
    private var ignore: String? {
        didSet {
            guard let ignoreNames = ignore else { return }
            ignoredUnusedNames = ignoreNames.split(separator: ",")
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }
    
    @Option(name: .long, help: "Path to the .assetcheckerignore file.")
    private var ignoreFile: String?
    
    @Option(name: .long, help: "Name of the SwiftGen enumerations to check against, comma-separated")
    private var swiftGenEnums: String? {
        didSet {
            guard let enumNames = swiftGenEnums else { return }
            swiftGenEnumNames = enumNames.split(separator: ",")
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }
    
    private var ignoredUnusedNames: [String] = []
    
    private var swiftGenEnumNames: [String] = []
    
    mutating public func run() throws {
        processIgnoreFile()
        print("Searching sources in \(source) for assets in \(assetCatalogPaths)")
        let availableAssets = listAssets()
        let availableAssetNames = Set(availableAssets.map{$0.asset} )
        let usedAssets = listUsedAssetLiterals()
        let usedAssetNames = Set(usedAssets.keys + ignoredUnusedNames)

        // Generate Warnings for Unused Assets
        let unused = availableAssets.filter { (asset, catalog) -> Bool in !usedAssetNames.contains(asset) && !isIgnored(asset) }
        unused.forEach { print("\($1):: warning: [Asset Unused] \($0)") }

        // Generate Error for broken Assets
        let broken = usedAssets.filter { (assetName, references) -> Bool in !availableAssetNames.contains(assetName) && !isIgnored(assetName) }
        broken.forEach { print("\($1.first ?? $0):: error: [Asset Missing] \($0)") }

        if broken.count > 0 {
            throw AssetCheckerError(brokenAssetCount: broken.count)
        }
    }
    
    lazy var assetCatalogPaths: [String] = {
        if let providedCatalog = catalog {
            return [providedCatalog]
        } else {
            // detect automatically
            return elementsInEnumerator(FileManager.default.enumerator(atPath: source)).filter { $0.hasSuffix(".xcassets") }
        }
    }()
}
extension AssetChecker {
    private func elementsInEnumerator(_ enumerator: FileManager.DirectoryEnumerator?) -> [String] {
        var elements = [String]()
        while let e = enumerator?.nextObject() as? String {
            elements.append(e)
        }
        return elements
    }

    /// Search for asset catalogs within the source path

    /// Process the ignore file
    private mutating func processIgnoreFile() {
        let ignoreFilePath = ignoreFile ?? "\(FileManager.default.currentDirectoryPath)/.assetcheckerignore"
        guard let data = try? String(contentsOfFile: ignoreFilePath, encoding: .utf8) else { return }
        ignoredUnusedNames = data.components(separatedBy: .newlines)
    }

    /// If the asset should be ignored
    private func isIgnored(_ assetName: String) -> Bool {
        let ignoreCount = ignoredUnusedNames.reduce(0) { (sum, ignore) -> Int in
            let ignoreRegex = try? NSRegularExpression(pattern: ignore, options: [])
            return sum + (ignoreRegex?.numberOfMatches(in: assetName, options: [], range: NSRange(location: 0, length: assetName.count)) ?? 0)
        }
        return ignoreCount > 0
    }

    /// List assets in found asset catalogs
    private mutating func listAssets() -> [(asset: String, catalog: String)] {
        
        return assetCatalogPaths.flatMap { (catalog) -> [(asset: String, catalog: String)] in
            
            let extensionName = "imageset"
            let enumerator = FileManager.default.enumerator(atPath: catalog)
            return elementsInEnumerator(enumerator)
                .filter { $0.hasSuffix(extensionName) }                             // Is Asset
                .map { $0.replacingOccurrences(of: ".\(extensionName)", with: "") } // Remove extension
                .map { $0.components(separatedBy: "/").last ?? $0 }                 // Remove folder path
                .map { (asset: $0, catalog: catalog)}
        }
    }

    /// List Assets used in the codebase, with the asset name as the key
    private func listUsedAssetLiterals() -> [String: [String]]  {
        let enumerator = FileManager.default.enumerator(atPath: source)
        
        var assetUsageMap: [String: [String]] = [:]
        
        // Only Swift and Obj-C files
        let files = elementsInEnumerator(enumerator)
            .filter { $0.hasSuffix(".m") || $0.hasSuffix(".swift") || $0.hasSuffix(".xib") || $0.hasSuffix(".storyboard") }
        
        /// Find sources of assets within the contents of a file
        func localizedStrings(inStringFile: String) -> [String] {
            var assetStringReferences = [String]()
            let namePattern = "([\\w-]+)"
            var patterns = [
                "#imageLiteral\\(resourceName: \"\(namePattern)\"\\)", // Image Literal
                "UIImage\\(named:\\s*\"\(namePattern)\"\\)", // Default UIImage call (Swift)
                "UIImage imageNamed:\\s*\\@\"\(namePattern)\"", // Default UIImage call
                "\\<image name=\"\(namePattern)\".*", // Storyboard resources
                "R.image.\(namePattern)\\(\\)" // R.swift support
            ]
            
            let swiftGenPatterns = swiftGenEnumNames.map { "\($0).\(namePattern).image" } // SwiftGen support
            patterns.append(contentsOf: swiftGenPatterns)
            
            for p in patterns {
                let regex = try? NSRegularExpression(pattern: p, options: [])
                let range = NSRange(location:0, length:(inStringFile as NSString).length)
                regex?.enumerateMatches(in: inStringFile,options: [], range: range) { result, _, _ in
                    if let r = result {
                        let value = (inStringFile as NSString).substring(with:r.range(at: 1))
                        assetStringReferences.append(value)
                    }
                }
            }
            return assetStringReferences
        }
        
        for filename in files {
            // Build file paths
            let filepath = "\(source)/\(filename)"
            
            // Get file contents
            if let fileContents = try? String(contentsOfFile: filepath, encoding: .utf8) {
                // Find occurrences of asset names
                let references = localizedStrings(inStringFile: fileContents)
                
                // assemble the map
                for asset in references {
                    let updatedReferences = assetUsageMap[asset] ?? []
                    assetUsageMap[asset] = updatedReferences + [filename]
                }
            }
        }
        
        return assetUsageMap
    }
}

AssetChecker.main()
