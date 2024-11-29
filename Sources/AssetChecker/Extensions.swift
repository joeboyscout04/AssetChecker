import Foundation

extension FileManager.DirectoryEnumerator {
    
    func elementsInEnumerator() -> [String] {
        var elements = [String]()
        while let e = nextObject() as? String {
            elements.append(e)
        }
        return elements
    }
}
