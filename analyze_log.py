
import re

log_file = 'build_log_simple.txt'

try:
    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    print("FULL LOG CONTENT:")
    print(content)

except Exception as e:
    print(f"Error reading log: {e}")
