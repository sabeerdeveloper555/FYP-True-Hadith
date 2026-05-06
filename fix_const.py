import re

errors_str = """
  error - lib\screens\result_detail_page.dart:219:22 - Methods can't be invoked in constant expressions. - const_eval_method_invocation
  error - lib\screens\result_detail_page.dart:231:22 - Methods can't be invoked in constant expressions. - const_eval_method_invocation
  error - lib\screens\result_detail_page.dart:283:16 - Methods can't be invoked in constant expressions. - const_eval_method_invocation
  error - lib\screens\result_page.dart:69:20 - Methods can't be invoked in constant expressions. - const_eval_method_invocation
  error - lib\screens\result_page.dart:241:26 - Methods can't be invoked in constant expressions. - const_eval_method_invocation
  error - lib\screens\voice_input_page.dart:33:20 - Methods can't be invoked in constant expressions. - const_eval_method_invocation
  error - lib\screens\voice_input_page.dart:98:32 - Methods can't be invoked in constant expressions. - const_eval_method_invocation
"""

errors = []
for line in errors_str.split('\n'):
    if 'const_eval_method_invocation' in line:
        m = re.search(r'lib\\screens\\([a-zA-Z0-9_\.\\\/]+\.dart):(\d+):', line)
        if m:
            errors.append((m.group(1).replace('\\', '/'), int(m.group(2))))

print(f"Found {len(errors)} const errors")

import collections
files_to_fix = collections.defaultdict(list)
for f, l in set(errors):
    files_to_fix[f].append(l)

for file_path, lines in files_to_fix.items():
    file_path = 'lib/screens/' + file_path
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content_lines = f.read().split('\n')
        
    for l in sorted(lines, reverse=True):
        idx = l - 1
        
        # Search backwards to remove 'const'
        for i in range(idx, max(-1, idx-15), -1):
            if 'const ' in content_lines[i]:
                if 'const Text(' in content_lines[i] or 'const  Text(' in content_lines[i]:
                    content_lines[i] = content_lines[i].replace('const Text(', 'Text(')
                    break
                elif 'const TextStyle(' in content_lines[i]:
                    content_lines[i] = content_lines[i].replace('const TextStyle(', 'TextStyle(')
                    break
                elif 'const Icon(' in content_lines[i]:
                    content_lines[i] = content_lines[i].replace('const Icon(', 'Icon(')
                    break
                elif 'const Center(' in content_lines[i]:
                    content_lines[i] = content_lines[i].replace('const Center(', 'Center(')
                    break
                elif 'const Padding(' in content_lines[i]:
                    content_lines[i] = content_lines[i].replace('const Padding(', 'Padding(')
                    break
                else:
                    content_lines[i] = re.sub(r'\bconst\s+', '', content_lines[i])
                    break
                    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(content_lines))
        
print("Const fixes applied.")
