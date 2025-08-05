#!/usr/bin/env python3
import sys
import subprocess

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 run_with_timeout.py <timeout_seconds> <command...>")
        sys.exit(1)
    try:
        timeout = int(sys.argv[1])
    except ValueError:
        sys.exit(1)
    command = sys.argv[2:]
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate(timeout=timeout)
        sys.stdout.buffer.write(stdout)
        sys.stderr.buffer.write(stderr)
        sys.exit(process.returncode)
    except subprocess.TimeoutExpired:
        print(f"\n--- TIMEOUT: Command exceeded {timeout} seconds ---", file=sys.stderr)
        process.kill()
        sys.exit(124)
    except Exception:
        sys.exit(1)

if __name__ == "__main__":
    main()