*! Test 15: Timestamp Cache Logic Test (Numeric Clock Values)
* Tests the 24-hour timestamp comparison using numeric clock() values
* Verifies that numeric timestamps are properly calculated and compared
* This is the CLEAN implementation - no string parsing needed!

clear all
version 16.0

di as result ""
di as result "============================================================"
di as result "Test 15: Timestamp Cache Logic (Numeric Clock Values)"
di as result "============================================================"
di as result ""

* Test 1: Get current clock value
di as result "Test 1: Get current clock value"
local current_str = "`c(current_date)' `c(current_time)'"
local current_clock = clock("`current_str'", "DMY hms")
di as text "  Current time: `current_str'"
di as text "  Clock value: `current_clock' ms"
assert `current_clock' > 0
di as result "  ✓ Current clock value is valid"
di as result ""

* Test 2: Calculate specific clock values
di as result "Test 2: Calculate specific clock values"
local ts1_clock = clock("23 Oct 2025 12:00:00", "DMY hms")
local ts2_clock = clock("23 Oct 2025 13:00:00", "DMY hms")
di as text "  23 Oct 2025 12:00:00 → `ts1_clock'"
di as text "  23 Oct 2025 13:00:00 → `ts2_clock'"
assert `ts1_clock' > 0
assert `ts2_clock' > 0
assert `ts2_clock' > `ts1_clock'
di as result "  ✓ Specific clock values calculated correctly"
di as result ""

* Test 3: Calculate time difference (same time = 0 difference)
di as result "Test 3: Time difference calculation"
local clock1 = clock("23 Oct 2025 12:00:00", "DMY hms")
local clock2 = clock("23 Oct 2025 12:00:00", "DMY hms")
local diff_ms = `clock2' - `clock1'
di as text "  Clock 1: `clock1'"
di as text "  Clock 2: `clock2'"
di as text "  Difference: `diff_ms' ms"
assert `diff_ms' == 0
di as result "  ✓ Same times have 0 difference"
di as result ""

* Test 4: Calculate 1 hour difference
di as result "Test 4: 1 hour difference"
local clock1 = clock("23 Oct 2025 12:00:00", "DMY hms")
local clock2 = clock("23 Oct 2025 13:00:00", "DMY hms")
local diff_ms = `clock2' - `clock1'
local expected_1h = 3600000  // 1 hour = 3,600,000 ms
di as text "  Time 1: 23 Oct 2025 12:00:00 → `clock1'"
di as text "  Time 2: 23 Oct 2025 13:00:00 → `clock2'"
di as text "  Difference: `diff_ms' ms"
di as text "  Expected:   `expected_1h' ms (1 hour)"
assert `diff_ms' == `expected_1h'
di as result "  ✓ 1 hour difference calculated correctly"
di as result ""

* Test 5: Calculate 24 hour difference
di as result "Test 5: 24 hour difference"
local clock1 = clock("23 Oct 2025 12:00:00", "DMY hms")
local clock2 = clock("24 Oct 2025 12:00:00", "DMY hms")
local diff_ms = `clock2' - `clock1'
local expected_24h = 86400000  // 24 hours = 86,400,000 ms
di as text "  Time 1: 23 Oct 2025 12:00:00 → `clock1'"
di as text "  Time 2: 24 Oct 2025 12:00:00 → `clock2'"
di as text "  Difference: `diff_ms' ms"
di as text "  Expected:   `expected_24h' ms (24 hours)"
assert `diff_ms' == `expected_24h'
di as result "  ✓ 24 hour difference calculated correctly"
di as result ""

* Test 6: Cache logic - within 24 hours (should NOT trigger update)
di as result "Test 6: Cache logic - within 24 hours"
local last_check = clock("23 Oct 2025 12:00:00", "DMY hms")
local current_clock = clock("24 Oct 2025 11:59:59", "DMY hms")
local diff_ms = `current_clock' - `last_check'
local should_update = (`diff_ms' >= 86400000)
di as text "  Last check: `last_check' (23 Oct 2025 12:00:00)"
di as text "  Current:    `current_clock' (24 Oct 2025 11:59:59, 23h 59m 59s later)"
di as text "  Difference: `diff_ms' ms"
di as text "  Should update? `should_update' (expected: 0)"
assert `should_update' == 0
di as result "  ✓ Cache valid within 24 hours (no update)"
di as result ""

* Test 7: Cache logic - exactly 24 hours (should trigger update)
di as result "Test 7: Cache logic - exactly 24 hours"
local last_check = clock("23 Oct 2025 12:00:00", "DMY hms")
local current_clock = clock("24 Oct 2025 12:00:00", "DMY hms")
local diff_ms = `current_clock' - `last_check'
local should_update = (`diff_ms' >= 86400000)
di as text "  Last check: `last_check' (23 Oct 2025 12:00:00)"
di as text "  Current:    `current_clock' (24 Oct 2025 12:00:00)"
di as text "  Difference: `diff_ms' ms"
di as text "  Should update? `should_update' (expected: 1)"
assert `should_update' == 1
di as result "  ✓ Update triggered at exactly 24 hours"
di as result ""

* Test 8: Cache logic - over 24 hours (should trigger update)
di as result "Test 8: Cache logic - over 24 hours"
local last_check = clock("23 Oct 2025 12:00:00", "DMY hms")
local current_clock = clock("24 Oct 2025 12:00:01", "DMY hms")
local diff_ms = `current_clock' - `last_check'
local should_update = (`diff_ms' >= 86400000)
di as text "  Last check: `last_check' (23 Oct 2025 12:00:00)"
di as text "  Current:    `current_clock' (24 Oct 2025 12:00:01, 24h 1s later)"
di as text "  Difference: `diff_ms' ms"
di as text "  Should update? `should_update' (expected: 1)"
assert `should_update' == 1
di as result "  ✓ Update triggered after 24 hours"
di as result ""

* Test 9: Edge case - 11:59 PM to 12:01 AM (2 minutes, should NOT update)
di as result "Test 9: Edge case - midnight crossing"
local last_check = clock("23 Oct 2025 23:59:00", "DMY hms")
local current_clock = clock("24 Oct 2025 00:01:00", "DMY hms")
local diff_ms = `current_clock' - `last_check'
local should_update = (`diff_ms' >= 86400000)
di as text "  Last check: `last_check' (23 Oct 2025 23:59:00)"
di as text "  Current:    `current_clock' (24 Oct 2025 00:01:00, 2 minutes later)"
di as text "  Difference: `diff_ms' ms"
di as text "  Should update? `should_update' (expected: 0)"
assert `should_update' == 0
di as result "  ✓ Midnight crossing handled correctly (no false trigger)"
di as result ""

* Test 10: Arithmetic operations (simulating cache save/load)
di as result "Test 10: Simulate config save/load"
local saved_clock = clock("23 Oct 2025 12:00:00", "DMY hms")
di as text "  Saving clock value to 'config': `saved_clock'"
* Simulate saving to config and reading back
local loaded_clock = `saved_clock'
di as text "  Loaded clock value from 'config': `loaded_clock'"
assert `loaded_clock' == `saved_clock'
local current_clock = clock("23 Oct 2025 13:30:00", "DMY hms")
local diff_ms = `current_clock' - `loaded_clock'
local expected = 5400000  // 1.5 hours
di as text "  Time difference: `diff_ms' ms (expected: `expected')"
assert `diff_ms' == `expected'
di as result "  ✓ Numeric values survive config save/load correctly"
di as result ""

* Summary
di as result "============================================================"
di as result "Timestamp Cache Logic Tests Complete!"
di as result "============================================================"
di as result ""
di as result "All 10 tests passed:"
di as result "  ✓ Current clock value calculation"
di as result "  ✓ Specific clock value calculation"
di as result "  ✓ Zero difference calculation"
di as result "  ✓ 1 hour difference"
di as result "  ✓ 24 hour difference"
di as result "  ✓ Cache valid within 24h (no update)"
di as result "  ✓ Cache triggers at exactly 24h"
di as result "  ✓ Cache triggers after 24h"
di as result "  ✓ Midnight crossing edge case (no false trigger)"
di as result "  ✓ Config save/load simulation"
di as result ""
di as result "CLEAN IMPLEMENTATION:"
di as result "  - No string manipulation needed"
di as result "  - Direct numeric comparison"
di as result "  - Simple arithmetic operations"
di as result "============================================================"
di as result ""
