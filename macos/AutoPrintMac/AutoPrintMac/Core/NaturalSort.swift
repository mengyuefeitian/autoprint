import Foundation

func naturalLessThan(_ lhs: String, _ rhs: String) -> Bool {
    lhs.compare(rhs, options: [.numeric, .caseInsensitive], locale: .current) == .orderedAscending
}
