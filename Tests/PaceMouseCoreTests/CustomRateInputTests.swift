import PaceMouseCore
import Testing

@Test
func customRateInputAcceptsOnlyIntegersWithinRange() {
    #expect(CustomRateInput.value(from: "100") == 100)
    #expect(CustomRateInput.value(from: "250") == 250)
    #expect(CustomRateInput.value(from: "500") == 500)

    for input in ["", "99", "501", "100.5", "250.0", "+100", " 250 ", "abc"] {
        #expect(CustomRateInput.value(from: input) == nil)
    }
}

@Test
func customRateInputRejectsInvalidTextDuringEditing() {
    for input in ["", "1", "10", "99", "100", "250", "500"] {
        #expect(CustomRateInput.isValidPartial(input))
    }

    for input in ["501", "999", "100.5", "250.0", "+100", " 250", "abc", "1000"] {
        #expect(!CustomRateInput.isValidPartial(input))
    }
}
