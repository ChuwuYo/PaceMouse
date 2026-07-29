import Foundation
import PaceMouseCore

final class CustomRateFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        if let string = obj as? String {
            return string
        }
        if let number = obj as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        obj?.pointee = string as NSString
        return true
    }

    override func isPartialStringValid(
        _ partialString: AutoreleasingUnsafeMutablePointer<NSString>,
        proposedSelectedRange proposedSelection: NSRangePointer?,
        originalString original: String,
        originalSelectedRange originalSelection: NSRange,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        CustomRateInput.isValidPartial(partialString.pointee as String)
    }
}
