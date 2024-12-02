import Foundation

public struct AssetCheckerError: Error {
    let brokenAssetCount: Int
    
    public init(brokenAssetCount: Int) {
        self.brokenAssetCount = brokenAssetCount
    }
}
extension AssetCheckerError: CustomStringConvertible {
    public var description: String {
        "👮‍♀️ There were \(brokenAssetCount) broken assets found!"
    }
}
