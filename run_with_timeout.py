#!/usr/bin/env python3
import sys, subprocess, signal, time

def run_with_timeout(timeout_seconds, *cmd_args):
    try:
        proc = subprocess.Popen(cmd_args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        stdout, _ = proc.communicate(timeout=timeout_seconds)
        print(stdout.decode(), end='')
        return proc.returncode
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.communicate()
        return 124  # Standard timeout exit code

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 run_with_timeout.py <timeout> <command> [args...]")
        sys.exit(1)
    
    timeout = int(sys.argv[1])
    cmd = sys.argv[2:]
    exit_code = run_with_timeout(timeout, *cmd)
    sys.exit(exit_code)
