#!/usr/bin/env python3
"""Stand-in for the macOS `fm` tool so tests run without the real model.

Behaviour is selected with the FAKE_FM_MODE environment variable. The received
argument list is appended to FAKE_FM_LOG when that variable is set, so tests
can assert on how the backend invoked the tool.
"""

import json
import os
import sys
import time

MODE = os.environ.get("FAKE_FM_MODE", "ok")
TOKENS = os.environ.get("FAKE_FM_TOKENS", "120")
RESPONSE = os.environ.get("FAKE_FM_RESPONSE", '{"summary": "s", "key_points": ["k"]}')


def log_call(argv):
    log_path = os.environ.get("FAKE_FM_LOG")
    if not log_path:
        return
    record = {"argv": argv}
    if "--schema" in argv:
        with open(argv[argv.index("--schema") + 1], encoding="utf-8") as handle:
            record["schema"] = json.load(handle)
    with open(log_path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")


def main():
    argv = sys.argv[1:]
    log_call(argv)
    command = argv[0] if argv else ""

    if command == "models":
        mark = "✗" if MODE == "model_not_ready" else "✓"
        print(f"Apple Foundation Models\n  {mark} system (Fake)\n  ✗ pcc (not available in this context)")
        return 1

    if command == "count-tokens":
        print(TOKENS)
        return 0

    if command == "respond":
        sys.stdin.read()
        if MODE == "hang":
            time.sleep(30)
        if MODE == "overflow":
            sys.stderr.write(
                "Error: \x1b[38;2;255;107;128mThe session's transcript exceeded the model's context size.\x1b[0m\n"
            )
            return 1
        if MODE == "unavailable":
            sys.stderr.write("Error: Apple Intelligence is not enabled on this device.\n")
            return 1
        if MODE == "crash":
            sys.stderr.write("Error: something unexpected\n")
            return 1
        print("\x1b[1m" + RESPONSE + "\x1b[0m")
        return 0

    sys.stderr.write("unknown command\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
