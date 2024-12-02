import Foundation
import ArgumentParser
import AssetCheckerLib

public struct AssetChecker: ParsableCommand {
    public init() {}
    
    public static var configuration = CommandConfiguration(
        abstract: "AssetChecker 👮‍♀️",
        version: "0.4.0")
    
    @Option(name: .long, help: "The path to the source code you want to check.")
    private var source: String = FileManager.default.currentDirectoryPath

    @Option(name: .long, help: "The asset catalog to check for extra assets.  Omitting this argument will search for asset catalogs.")
    private var catalog: String?
    
    @Option(name: .long, help: "Comma-separated asset names to ignore")
    private var ignore: String?
    
    @Option(name: .long, help: "Path to the .assetcheckerignore file.")
    private var ignoreFile: String?
    
    @Option(name: .long, help: "Prefixes used in SwiftGen patterns to check, comma-separated")
    private var swiftgenPrefixes: String?
    
    private var ignoredUnusedNames: [String] = []
    private var parsedSwiftgenPrefixes: [String] = []
    
    mutating public func run() throws {
        
        let parsedSwiftgenPrefixes = swiftgenPrefixes?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let ignoredUnusedNames = ignore?.split(separator: ",")
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let fileLocator = AssetFileLocator(
            sourcePath: source,
            catalog: catalog,
            ignoredUnusedNames: ignoredUnusedNames ?? [],
            ignoreFile: ignoreFile,
            swiftgenPrefixes: parsedSwiftgenPrefixes ?? [])
        print("Searching sources in \(source) for assets in \(fileLocator.assetCatalogPaths)")
        
        let results = fileLocator.checkAssets()

        // Generate Warnings for Unused Assets
        results.unusedAssets.forEach {
            print("\($0.catalog): warning: [Asset Unused] \($0.asset)")
        }

        // Generate Error for broken Assets
        results.brokenAssets.forEach {
            print("\($1.first ?? $0): error: [Asset Missing] \($0)")
        }

        if results.brokenAssets.count > 0 {
            throw AssetCheckerError(brokenAssetCount: results.brokenAssets.count)
        }
    }
}

AssetChecker.main()
