#!/bin/bash
# Shared jq helper functions for PR review scripts

# Priority detection function for various code review bot formats
# Supports: Gemini, Cursor, Claude, and general markdown priority markers
PRIORITY_DETECT='
    def detect_priority:
        # Gemini format: ![critical], ![high], ![medium], ![low]
        if test("!\\[critical\\]"; "i") then "critical"
        elif test("!\\[high\\]"; "i") then "high"
        elif test("!\\[medium\\]"; "i") then "medium"
        elif test("!\\[low\\]"; "i") then "low"
        # Cursor format: <!-- **High Severity** -->
        elif test("Critical Severity"; "i") then "critical"
        elif test("High Severity"; "i") then "high"
        elif test("Medium Severity"; "i") then "medium"
        elif test("Low Severity"; "i") then "low"
        # Claude/general markdown: **Critical**, ### Critical, CRITICAL:
        elif test("\\*\\*Critical"; "i") or test("### Critical"; "i") or test("CRITICAL:"; "") then "critical"
        elif test("\\*\\*High"; "i") or test("### High"; "i") or test("HIGH:"; "") then "high"
        elif test("\\*\\*Medium"; "i") or test("### Medium"; "i") or test("MEDIUM:"; "") then "medium"
        elif test("\\*\\*Low"; "i") or test("### Low"; "i") or test("LOW:"; "") then "low"
        # Cursor Bug headers
        elif test("### Bug:"; "") then "high"
        elif test("### Issue:"; "") then "medium"
        elif test("### Suggestion:"; "") then "low"
        else "unknown"
        end;
'

export PRIORITY_DETECT
