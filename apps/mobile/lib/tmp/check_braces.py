
import sys

def check_braces(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    level = 0
    for i, line in enumerate(lines):
        for char in line:
            if char == '{':
                level += 1
            elif char == '}':
                level -= 1
        if level == 0 and i > 100: # Only care about level 0 after class starts
             print(f"Level 0 at line {i+1}: {line.strip()}")
             # break # Find the first one

if __name__ == "__main__":
    check_braces(sys.argv[1])
