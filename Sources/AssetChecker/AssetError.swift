
import Foundation

struct AssetCheckerError: Error {
    let brokenAssetCount: Int
}
extension AssetCheckerError: CustomStringConvertible {
    var description: String {
        "👮‍♀️ There were \(brokenAssetCount) broken assets found!"
    }
}
