public enum CustomRateInput {
    public static let range = 100...500

    public static func value(from input: String) -> Int? {
        guard isASCIIDecimal(input), let value = Int(input), range.contains(value) else {
            return nil
        }
        return value
    }

    public static func isValidPartial(_ input: String) -> Bool {
        guard !input.isEmpty else { return true }
        guard isASCIIDecimal(input), input.utf8.count <= 3 else { return false }
        return input.utf8.count < 3 || value(from: input) != nil
    }

    private static func isASCIIDecimal(_ input: String) -> Bool {
        !input.isEmpty && input.utf8.allSatisfy { 48...57 ~= $0 }
    }
}
