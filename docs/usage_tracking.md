# RegiStream Usage Tracking System

**Added in:** RegiStream v2.0.0
**Privacy:** GDPR-Compliant, Anonymous, Opt-in for Online Sharing

---

## Overview

RegiStream includes a **two-tier usage tracking system**:

1. **Local Usage Logging** (default: enabled)
   - Like `.bash_history` - stays on your machine
   - **NOT a GDPR issue** (no data transmission)

2. **Online Telemetry** (default: disabled)
   - Opt-in only
   - Sends fully anonymous data to registream.org
   - **GDPR compliant** (anonymous, transparent, revocable)

---

## 1. Local Usage Logging

**Purpose:** Track your own RegiStream usage locally (never sent anywhere unless you explicitly export it).

**Location:** `~/.registream/usage_stata.csv`

**Format:**
```csv
timestamp;user_id;platform;version;command_string;os;platform_version
2025-10-20T17:38:19Z;1234567890;stata;2.0.0;autolabel variables kon, domain(scb) lang(eng);MacOSX;16.0
```

**7 Fields Logged:**
- `timestamp` - When command was run (ISO 8601)
- `user_id` - Anonymous hash (10 digits, see below)
- `platform` - "stata", "python", or "r"
- `version` - RegiStream version
- `command_string` - Full command (may include variable names)
- `os` - Operating system
- `platform_version` - Stata/Python/R version

**Commands:**
```stata
registream stats                         // View your statistics
registream config, usage_logging(false)  // Disable local logging
registream config, usage_logging(true)   // Re-enable local logging
```

**Access raw data:** `~/.registream/usage_stata.csv`

---

## 2. Online Telemetry

**Purpose:** Help improve RegiStream by sending anonymized usage data to registream.org.

**Default:** Disabled (opt-in only via Full Mode or manual config)

**What Gets Sent:** Same 7 fields as local logging (identical data, just sent to API)

**NOT Sent:**
- Dataset content
- Actual data values
- File paths
- Personal identifiers (user_id is cryptographically hashed)

**API Endpoint:** `https://registream.org/api/v1/stata/heartbeat` (HTTP GET)

**How It Works:** Telemetry is combined with version check in a single consolidated heartbeat request (performance optimization)

**Requirements:** Both `telemetry_enabled=true` AND `internet_access=true`

**Commands:**
```stata
registream config, telemetry_enabled(true)   // Enable
registream config, telemetry_enabled(false)  // Disable
registream info                              // Check current settings
```

**Behavior:**
- Silent operation (graceful failure)
- Never interrupts workflow
- Skipped silently if offline
- Sent via consolidated heartbeat (combines telemetry + version check)

---

## Configuration

### Config File

Location: `~/.registream/config.yaml`

| Setting | Default | Controls |
|---------|---------|----------|
| `usage_logging` | true | Local CSV logging |
| `telemetry_enabled` | false | Online data sending |
| `internet_access` | true | Metadata downloads + updates |
| `auto_update_check` | true | Package update checks |

### Three Modes

**Offline Mode:**
```stata
registream config, internet_access(false) telemetry_enabled(false)
```

**Standard Mode (recommended):**
```stata
registream config, internet_access(true) telemetry_enabled(false)
```

**Full Mode (help improve RegiStream):**
```stata
registream config, internet_access(true) telemetry_enabled(true)
```

---

## Anonymous User ID

**Generation:**
- SHA-256-inspired Mata implementation
- Per-installation salt (64 random characters stored in `~/.registream/.salt`)
- Hash format: 16-character hexadecimal (64-bit hash space)
- Computed locally using cryptographic hashing

**Properties:**
- Consistent across sessions on same machine
- Cryptographically secure - practically impossible to reverse-engineer without salt file
- Different users have different IDs
- Performance: ~0.34ms per hash (Mata-compiled)

**Example:** `4dd4730d0999bc07`

---

## Privacy & GDPR Compliance

### Local Usage Logging (NOT a GDPR issue)

Local logging stores data **only on your machine** - it never leaves your computer unless you manually share it.

**Why it's not a GDPR issue:**
- Stored locally only (~100 bytes per command)
- You have full control (delete file, disable logging anytime)
- No data transmission to any server

**Your control:**
- **View:** `registream stats` or `~/.registream/usage_stata.csv`
- **Delete:** `rm ~/.registream/usage_stata.csv`
- **Disable:** `registream config, usage_logging(false)`

---

### Online Telemetry (GDPR compliant)

When enabled, anonymized data is sent to `registream.org` to help improve RegiStream.

**GDPR Compliance:**
- **Opt-in only:** Disabled by default, requires explicit consent
- **Anonymous:** Uses cryptographically secure hash ID - cannot identify individuals
- **Transparent:** You know exactly what's sent (7 fields listed above)
- **Revocable:** Disable anytime with `registream config, telemetry_enabled(false)`

**For server-side data deletion:**

If you want data deleted from registream.org servers, email us at [support@registream.org] with:
1. Your anonymous user ID (from `registream stats`)
2. Request to delete your data

**Note:** Since the data is fully anonymous (one-way hash), we cannot identify you from the data alone. The anonymous ID is the only way to locate your specific data entries on our server.

---

## Multi-User Systems

Each user on shared systems (research servers) has:
- Their own anonymous ID
- Their own usage log
- Individual config control

**System-wide stats:**
```stata
registream stats all  // Aggregate across all users (anonymous)
```

---

## Developer Reference

**Wrapper Integration:**

Both commands call usage tracking wrapper:
- `autolabel.ado` → `_autolabel_wrapper_start`
- `registream.ado` → `_registream_wrapper_start`

**Local logging:**
```stata
_rs_config get "`registream_dir'" "usage_logging"
if (r(value) == "true") {
    _rs_usage log "`registream_dir'" "command_string" "version"
}
```

**Online telemetry:**
```stata
* Sent via consolidated heartbeat at end of command execution
* Combines telemetry + version check in single GET request
* Implementation in _rs_updates.ado (_upd_send_heartbeat)
if (telemetry_enabled == "true" & internet_access == "true") {
    * Heartbeat includes all 7 telemetry fields as URL parameters
    * GET /api/v1/stata/heartbeat?user_id=...&command=...&version=...
}
```

**Implementation:**
- Local logging: `stata/src/_rs_usage.ado`
- Online telemetry: `stata/src/_rs_updates.ado` (consolidated heartbeat)

---

## FAQ

**Q: What's the difference between local logging and online telemetry?**
- **Local logging:** Data stays on your machine (like `.bash_history`)
- **Online telemetry:** Sends anonymous data to registream.org to help improve the software

**Q: Is online telemetry enabled by default?**
- **Local logging:** Yes (but stays on your machine)
- **Online telemetry:** No (opt-in only)

**Q: Can I see what's being collected locally?**
Yes. View `~/.registream/usage_stata.csv` or run `registream stats`.

**Q: How do I disable local logging?**
```stata
registream config, usage_logging(false)
```

**Q: How do I disable online telemetry?**
```stata
registream config, telemetry_enabled(false)
```

**Q: Does this slow down commands?**
No. <10ms overhead, non-blocking.

**Q: What if I work offline?**
Local logging works normally. Online telemetry is silently skipped (no errors).

**Q: Can the RegiStream team see my data?**
Only if you explicitly enable online telemetry (`telemetry_enabled=true`). Even then, it's fully anonymous.

---

## Secure Systems

Administrators can pre-configure `~/.registream/config.yaml` to prevent user modifications:

```yaml
usage_logging: true
telemetry_enabled: false
internet_access: false
auto_update_check: false
```

Users can still use all features offline.

---

**Version:** 2.0.0
**Last Updated:** 2025-10-20
