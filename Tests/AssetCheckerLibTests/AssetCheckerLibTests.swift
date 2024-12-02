import XCTest
@testable import AssetCheckerLib

final class AssetCheckerTests: XCTestCase {
    
    private var mockFileManager: MockFileManager!
    private let sourcePath = "ExampleProject"
    private let catalogName = "Assets.xcassets"
    
    private let sourceFileContent = """
        class UsingAssets {
            
            let imageLiteral = #imageLiteral(resourceName: "literal-image")
            let imageNamed = UIImage(named: "named-image")
            let imageNamedObjc = [UIImage imageNamed:@"named-objc-image"]
            let imageStoryboard = <image name="storyboard-image"/>
            let imageRswift = R.image.rswiftImage()
            let imageSwiftgen = Asset.swiftGenImage.image
            let imageResource = UIImage(resource: .resourceImage)
            let imageSwiftUI = Image("swiftui-image")
            let imageSwiftResource = Image(.swiftUIResourceImage)
            let imageSwiftUIKit = Image(uiImage: .swiftuiKitImage)
            
        }
    """
    
    override func setUp() {
        super.setUp()
        // Mock FileManager to avoid actual file IO
        mockFileManager = MockFileManager()
        mockFileManager.sourcePath = sourcePath
    }
    
    override func tearDown() {
        mockFileManager = nil
        super.tearDown()
    }
    
    func testInitWithSingleCatalog() {
        
        let sut = AssetFileLocator(sourcePath: sourcePath,
                                   catalog: catalogName,
                                   ignoredUnusedNames: [],
                                   ignoreFile: nil,
                                   swiftgenPrefixes: [],
                                   fileManager: mockFileManager)
        
        
        XCTAssertEqual(sut.sourcePath, sourcePath)
        XCTAssertEqual(sut.assetCatalogPaths, [catalogName])
        XCTAssertEqual(sut.ignoredUnusedNames, [])
    }
    
    func testInitWithIgnoreFile() {

        mockFileManager.sourceFileContent = """
        ignored-asset
        second-ignored-asset
        """
        
        let sut = AssetFileLocator(sourcePath: sourcePath,
                                   catalog: catalogName,
                                   ignoredUnusedNames: [],
                                   ignoreFile: nil,
                                   swiftgenPrefixes: [],
                                   fileManager: mockFileManager)
        
        XCTAssertEqual(sut.ignoredUnusedNames, ["ignored-asset", "second-ignored-asset"])
    }
    
    func testInitWithIgnoreNames() {
        
        let sut = AssetFileLocator(sourcePath: sourcePath,
                                   catalog: catalogName,
                                   ignoredUnusedNames: ["ignored-name"],
                                   ignoreFile: nil,
                                   swiftgenPrefixes: [],
                                   fileManager: mockFileManager)
        mockFileManager.sourceFileContent = """
        ignored-asset
        second-ignored-asset
        """
        
        XCTAssertEqual(sut.ignoredUnusedNames, ["ignored-name"])
    }
    
    func testInitDetectCatalogs() {
        let sourcePath = "test"
        
        mockFileManager.sourceFiles = ["test.swift", "Images.xcassets", "Resources/Assets.xcassets"]
        mockFileManager.sourcePath = sourcePath
        
        let sut = AssetFileLocator(sourcePath: sourcePath,
                                   catalog: nil,
                                   ignoredUnusedNames: [],
                                   ignoreFile: nil,
                                   swiftgenPrefixes: [],
                                   fileManager: mockFileManager)
        
        XCTAssertEqual(sut.assetCatalogPaths, ["Images.xcassets", "Resources/Assets.xcassets"])
    }
    
    func testCheckUnusedAssets() {
        
        let catalogName = "Assets"
        
        let catalogAssets = [
            "test_asset_1.imageset",
            "test-asset_2.imageset",
            "testAsset3.imageset"
        ]
        
        mockFileManager.assetFiles = catalogAssets
        
        let sut = AssetFileLocator(sourcePath: sourcePath,
                                   catalog: catalogName,
                                   ignoredUnusedNames: [],
                                   ignoreFile: nil,
                                   swiftgenPrefixes: [],
                                   fileManager: mockFileManager)
        
        let results = sut.checkAssets()
        
        XCTAssertEqual(results.unusedAssets, catalogAssets.map { AssetFileLocator.AssetAndCatalog(asset: $0.replacing(".imageset", with: ""), catalog: catalogName)})
    }
    
    func testCheckUsedAssets() {
        
        let catalogAssets = [
            "literal-image.imageset",
            "named-image.imageset",
            "named-objc-image.imageset",
            "storyboard-image.imageset",
            "rswift-image.imageset",
            "swift-gen-image.imageset",
            "resource-image.imageset",
            "swiftui-image.imageset",
            "swiftui-kit-image.imageset",
            "swiftui-resource-image.imageset"
        ]
        
        mockFileManager.sourcePath = sourcePath
        mockFileManager.assetFiles = catalogAssets
        mockFileManager.sourceFiles = ["SourceFile.swift"]
        mockFileManager.sourceFileContent = sourceFileContent
        
        let sut = AssetFileLocator(sourcePath: sourcePath,
                                   catalog: catalogName,
                                   ignoredUnusedNames: [],
                                   ignoreFile: nil,
                                   swiftgenPrefixes: ["Asset"],
                                   fileManager: mockFileManager)
        
        let results = sut.checkAssets()
        
        XCTAssertEqual(results.unusedAssets, [])
        XCTAssertEqual(results.brokenAssets, [:])
    }
    
    func testCheckBrokenAssets() {
        
        mockFileManager.sourcePath = sourcePath
        mockFileManager.assetFiles = []
        mockFileManager.sourceFiles = ["SourceFile.swift"]
        mockFileManager.sourceFileContent = sourceFileContent
        
        let sut = AssetFileLocator(sourcePath: sourcePath,
                                   catalog: catalogName,
                                   ignoredUnusedNames: [],
                                   ignoreFile: nil,
                                   swiftgenPrefixes: ["Asset"],
                                   fileManager: mockFileManager)
        
        let results = sut.checkAssets()
        
        let expectedPath = ["\(sourcePath)/\(mockFileManager.sourceFiles.first!)"]
        XCTAssertEqual(results.unusedAssets, [])
        XCTAssertEqual(results.brokenAssets, ["literal-image": expectedPath,
                                              "named-image": expectedPath,
                                              "named-objc-image": expectedPath,
                                              "storyboard-image": expectedPath,
                                              "rswiftImage": expectedPath,
                                              "swiftGenImage": expectedPath,
                                              "resourceImage": expectedPath,
                                              "swiftui-image": expectedPath,
                                              "swiftuiKitImage": expectedPath,
                                              "swiftUIResourceImage": expectedPath])
    }
}

private final class MockFileManager: FileManager {
    
    var assetFiles: [String] = []
    var sourceFiles: [String] = []
    var sourceFileContent: String?
    var sourcePath: String?
    
    override func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator? {
        if sourcePath == path {
            return MockDirectoryEnumerator(files: sourceFiles)
        } else {
            return MockDirectoryEnumerator(files: assetFiles)
        }
    }
    
    override func contents(atPath path: String) -> Data? {
        // Return mock content for files
        return sourceFileContent?.data(using: .utf8)
    }
}

// MARK: - Mock DirectoryEnumerator
private final class MockDirectoryEnumerator: FileManager.DirectoryEnumerator {
    
    var files: [String]
    private var currentIndex = 0
    
    init(files: [String]) {
        self.files = files
    }
    
    override func nextObject() -> Any? {
        guard currentIndex < files.count else { return nil }
        let file = files[currentIndex]
        currentIndex += 1
        return file
    }
}
