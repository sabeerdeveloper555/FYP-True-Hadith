import re
import os

screens_dir = 'lib/screens'
files_to_modify = [
    'audio_trimming_page.dart',
    'chatbot_screen.dart',
    'crop_image_page.dart',
    'login_screen.dart',
    'reset_password_screen.dart',
    'bookmark_detail_page.dart',
    'bookmark_page.dart',
    'history_detail_page.dart',
    'history_page.dart',
    'onboarding_screen.dart',
    'result_detail_page.dart',
    'result_page.dart',
    'voice_input_page.dart'
]

mapping = {
    'AppColors.background': 'ThemeColors.background(isDark)',
    'AppColors.cardBackground': 'ThemeColors.card(isDark)',
    'AppColors.darkSurface': 'ThemeColors.surface(isDark)',
    'AppColors.inputBackground': 'ThemeColors.inputBackground(isDark)',
    'AppColors.textPrimary': 'ThemeColors.textPrimary(isDark)',
    'AppColors.textSecondary': 'ThemeColors.textSecondary(isDark)',
    'AppColors.textLight': 'ThemeColors.textLight(isDark)',
    'AppColors.border': 'ThemeColors.border(isDark)',
    'AppColors.divider': 'ThemeColors.divider(isDark)',
    'AppColors.shadow': 'ThemeColors.shadow(isDark)',
    'AppColors.shimmerBase': 'ThemeColors.shimmerBase(isDark)',
    'AppColors.shimmerHighlight': 'ThemeColors.shimmerHighlight(isDark)'
}

for filename in files_to_modify:
    filepath = os.path.join(screens_dir, filename)
    if not os.path.exists(filepath):
        continue
        
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    original = content
    
    # 1. Inject `final isDark = Theme.of(context).brightness == Brightness.dark;`
    # Replace `Widget method(..., BuildContext context, ...) {`
    def repl_build(m):
        groups = m.groups()
        method_name = groups[0]
        params = groups[1]
        
        ctx_match = re.search(r'BuildContext\s+([a-zA-Z0-9_]+)', params)
        ctx_var = ctx_match.group(1) if ctx_match else "context"
        
        return f"Widget {method_name}({params}) {{\n    final isDark = Theme.of({ctx_var}).brightness == Brightness.dark;"
        
    content = re.sub(r'Widget\s+([a-zA-Z0-9_]+)\s*\(([^)]*BuildContext\s+[a-zA-Z0-9_]+[^)]*)\)\s*\{', repl_build, content)
    
    # 2. Replace AppColors
    for k, v in mapping.items():
        content = content.replace(k, v)
        
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")
