#!/usr/bin/env python3
"""
TTZip JetBrains IDEA Style Test Reporter
Parses `swift test` stdout/stderr and formats it into a visual tree hierarchy with ANSI colors.
"""

import sys
import re
import time

# ANSI Color Codes
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
GRAY = "\033[90m"
BG_GREEN = "\033[42m\033[30m"
BG_RED = "\033[41m\033[37m"

def main():
    suite_pattern = re.compile(r"Test Suite '(?:.*\.xctest/Contents/MacOS/)?([^']+)' (started|passed|failed)")
    case_start_pattern = re.compile(r"Test Case '-\[\w+\.([^\s]+)\s+([^\]]+)\]' started\.")
    case_end_pattern = re.compile(r"Test Case '-\[\w+\.([^\s]+)\s+([^\]]+)\]' (passed|failed) \(([0-9\.]+) seconds\)\.")
    failure_location_pattern = re.compile(r"(.+\.swift):(\d+):\s+error:\s+-\[[^\]]+\]\s+:\s+(.+)")

    suites = {}  # suite_name -> list of test results
    current_suite = None
    passed_count = 0
    failed_count = 0
    start_time = time.time()
    failures = []

    print(f"\n{BOLD}{CYAN}🧪 [TTZip Test Runner] JetBrains IDE Visual Hierarchy Mode{RESET}\n")

    for line in sys.stdin:
        line_clean = line.rstrip()

        # Catch failure detail lines
        fail_match = failure_location_pattern.search(line_clean)
        if fail_match:
            file_path, line_no, msg = fail_match.groups()
            failures.append({
                "file": file_path,
                "line": line_no,
                "msg": msg,
                "suite": current_suite
            })
            continue

        # Catch Suite start/end
        suite_match = suite_pattern.search(line_clean)
        if suite_match:
            name, status = suite_match.groups()
            if name in ("Selected tests", "All tests") or name.endswith(".xctest"):
                continue

            if status == "started":
                current_suite = name
                if name not in suites:
                    suites[name] = []
                    print(f"  {BOLD}📂 {name}{RESET}")
            elif status in ("passed", "failed"):
                current_suite = None
            continue

        # Catch Test Case end
        case_end_match = case_end_pattern.search(line_clean)
        if case_end_match:
            suite_name, test_method, status, duration_str = case_end_match.groups()
            duration_ms = float(duration_str) * 1000.0

            if status == "passed":
                passed_count += 1
                badge = f"{GREEN}✔ PASSED{RESET}"
                icon = f"{GREEN}✔{RESET}"
            else:
                failed_count += 1
                badge = f"{RED}✖ FAILED{RESET}"
                icon = f"{RED}✖{RESET}"

            time_display = f"{GRAY}({duration_ms:.1f}ms){RESET}" if duration_ms < 1000 else f"{YELLOW}({duration_str}s){RESET}"

            print(f"    ├─ {icon} {BOLD}{test_method}{RESET} {badge} {time_display}")
            suites.setdefault(suite_name, []).append({
                "name": test_method,
                "status": status,
                "duration": duration_str
            })
            sys.stdout.flush()
            continue

    total_time = time.time() - start_time
    total_tests = passed_count + failed_count

    # Failure Details Report
    if failures:
        print(f"\n{BOLD}{RED}💥 [Failure Diagnostics & Stack Traces]{RESET}")
        print("─" * 80)
        for idx, f in enumerate(failures, 1):
            print(f"  {RED}{idx}. {f['msg']}{RESET}")
            print(f"     📍 Location: {CYAN}{f['file']}:{f['line']}{RESET}\n")

    # JetBrains IDE Bottom Summary Banner
    print("\n" + "═" * 80)
    if failed_count == 0 and total_tests > 0:
        status_banner = f"{BG_GREEN}  TEST RUN PASSED  {RESET}"
    elif failed_count > 0:
        status_banner = f"{BG_RED}  TEST RUN FAILED  {RESET}"
    else:
        status_banner = f"{BOLD}{YELLOW}  NO TESTS EXECUTED  {RESET}"

    print(f" {status_banner}  {BOLD}Total: {total_tests}{RESET} | {GREEN}Passed: {passed_count}{RESET} | {RED}Failed: {failed_count}{RESET} | {GRAY}Time: {total_time:.2f}s{RESET}")
    print("═" * 80 + "\n")

    if failed_count > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
