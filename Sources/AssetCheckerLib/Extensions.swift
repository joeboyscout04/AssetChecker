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

extension String {
    func isAlphanumericMatch(with: String) -> Bool {
        // Remove non-alphanumeric characters and lowercase the strings
        let alphanumericSelf = self.filter { $0.isLetter || $0.isNumber }.lowercased()
        let alphanumericComparison = with.filter { $0.isLetter || $0.isNumber }.lowercased()
        return alphanumericSelf == alphanumericComparison
    }
}
