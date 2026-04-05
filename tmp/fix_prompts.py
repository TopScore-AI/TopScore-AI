import re

file_path = r'C:\Users\Veldrine\Projects\TutorAgent\managers\prompts.py'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Broadly replace the "NEVER attempt to generate" restriction
content = re.sub(
    r'\*\*NEVER attempt to generate, create, or synthesize images\*\*.*?\.',
    r'If no high-quality online image is found, or if the student needs a specific textbook-style diagram, you MUST call `generate_educational_diagram`. You are NO LONGER text-only—you have state-of-the-art visual generation capabilities.',
    content,
    flags=re.DOTALL
)

# 2. Fix the "If a diagram is needed, describe it clearly" line
content = re.sub(
    r'If a diagram is needed, describe it clearly or use the !\[Image of X\]\(URL\) tag if enabled\.',
    r'If a diagram is provided via tool, explain its components clearly to the student.',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Replacement complete.")
