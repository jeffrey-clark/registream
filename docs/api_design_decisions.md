# API Design Decisions

## Overview

This document explains the architectural choices for API communication between the Stata package and the RegiStream backend.

## The `format=stata` Parameter

### Why It Exists

**Problem:** Stata has severe regex limitations compared to modern languages:
- No POSIX character classes (`[[:space:]]`, `[[:digit:]]`, etc.)
- Limited lookahead/lookbehind support
- Weak JSON parsing capabilities

**Original approach (v2.0.0-2.0.1):**
```stata
* Failed because [[:space:]] doesn't work in Stata
if regexm(`"`json_line'"', `""version"[[:space:]]*:[[:space:]]*"([^"]+)""') {
    local version = regexs(1)
}
```

**Solution (v2.0.2+):**
Backend supports `?format=stata` parameter that returns simple key=value format:
```
version=2.0.2
update_available=false
latest_version=2.0.2
```

Stata parsing is trivial:
```stata
if (regexm("`line'", "^version=(.+)$")) {
    local version = trim(regexs(1))
}
```

## Format Selection Strategy

### key=value Format (Single-Record Responses)

**Used for:**
- `/api/v1/stata/version?format=stata`
- `/api/v1/stata/heartbeat?format=stata`
- `/api/v1/datasets/{domain}/{type}/{lang}/latest/info?format=stata`

**Characteristics:**
- 2-5 lines per response
- Simple regex parsing
- No dataset overhead
- **Speed: ~1-5ms**

**Parsing pattern:**
```stata
tempname fh
file open `fh' using "`response'", read text
file read `fh' line                    // Read FIRST
while (r(eof) == 0) {                  // Then check EOF
    if (regexm("`line'", "^key=(.+)$")) {
        local value = trim(regexs(1))
    }
    file read `fh' line                // Read next at end
}
file close `fh'
```

**Critical pattern:** Read-then-check EOF. `while (!r(eof))` doesn't work in Stata because `r(eof)` is set immediately after `file open`.

### CSV Format (Batch Responses)

**Used for:**
- `/api/v1/datasets/check_updates?datasets=...&format=stata`

**Characteristics:**
- 100+ rows (one per dataset)
- Native Stata CSV parser
- Robust handling of quotes, commas, special characters
- **Speed: Fast for large datasets**

**Parsing pattern:**
```stata
preserve
import delimited using "`response'", clear varnames(1)
* Process rows
restore
```

## Performance Comparison

| Format     | Lines | Method            | Speed    | Code Complexity |
|------------|-------|-------------------|----------|-----------------|
| key=value  | 2-5   | File I/O + regex  | ~1-5ms   | Medium          |
| CSV        | 2-5   | import delimited  | ~10-50ms | Low             |
| CSV        | 100+  | import delimited  | Fast     | Low             |

**Decision:** Use key=value for tiny responses (version/heartbeat), CSV for batch operations.

## Common Pitfalls

### 1. File Read Pattern

**Wrong:**
```stata
while (!r(eof)) {
    file read `fh' line
    * This never executes!
}
```

**Correct:**
```stata
file read `fh' line          // Read FIRST
while (r(eof) == 0) {        // Then check
    * Process line
    file read `fh' line      // Read next
}
```

### 2. Regex Escaping

**Wrong:**
```stata
if (regexm("`line'", "key=(.+)")) {  // Missing anchors
```

**Correct:**
```stata
if (regexm("`line'", "^key=(.+)$")) {  // Anchored
```

### 3. Value Trimming

Always trim extracted values:
```stata
local value = trim(regexs(1))  // Remove leading/trailing whitespace
```

## Multi-Platform Considerations

### Config File Separation (v2.0.2+)

Each platform gets its own config file to prevent overwrites:
- Stata: `~/.registream/config_stata.yaml`
- R: `~/.registream/config_r.yaml` (future)
- Python: `~/.registream/config_python.yaml` (future)

### API Format Parameter

The `format=stata` parameter is Stata-specific. Future platforms:
- R: Can use JSON natively (no format parameter needed)
- Python: Can use JSON natively (no format parameter needed)
- Stata: Requires `format=stata` for simple parsing

## Implementation Files

### Stata Package

- `_rs_updates.ado`: Version check, heartbeat, batch updates
- `_rs_autolabel_utils.ado`: Dataset info lookups
- `_rs_config.ado`: Config file operations (key=value YAML parsing)

### Backend API

- Flask route decorator: `@require_format_param` enforces format selection
- Response formatters: `format_stata()` and `format_csv()`

## Future Enhancements

### Possible Improvements

1. **All-CSV approach**: Replace key=value with single-row CSV
   - Pros: Zero regex, consistent format
   - Cons: Slight performance overhead for tiny responses
   - **Decision: Not worth it** - current approach is optimal

2. **Binary format**: For large dataset downloads
   - Pros: Smaller file size
   - Cons: Stata has poor binary support
   - **Decision: Keep zip/csv** - widely supported

3. **Caching headers**: HTTP cache control
   - Pros: Reduce server load
   - Cons: Stata `copy` command doesn't support HTTP headers
   - **Decision: Application-level caching** (24-hour cache in config)

## Lessons Learned

1. **Test with actual Stata runtime** - Syntax that looks correct may fail in practice (EOF pattern bug)
2. **Simple is better** - key=value beats JSON for Stata's limitations
3. **Match format to data size** - key=value for small, CSV for batch
4. **Document why, not just what** - Future maintainers need context (this file!)
5. **Platform-specific optimization** - Don't force R/Python to use Stata's workarounds

## References

- Stata file I/O: `help file`
- Regex in Stata: `help regexm`
- CSV import: `help import delimited`
- Backend API: `/api/v1/stata/` endpoints
