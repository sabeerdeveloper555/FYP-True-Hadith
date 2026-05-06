import os
import re

missing = {
    'lib/screens/audio_trimming_page.dart': ['void paint(Canvas canvas, Size size) {', 'Widget _buildLanguageButton('],
    'lib/screens/bookmark_detail_page.dart': ['Widget _buildErrorState() {', 'Widget _buildDetailContent() {', 'Widget _buildSectionTitle(String title) {'],
    'lib/screens/bookmark_page.dart': ['Widget _buildFilterTags() {', 'Widget _buildEmptyState() {', 'Widget _buildErrorState() {'],
    'lib/screens/chatbot_screen.dart': ['Widget _buildEmptyState() {', 'Widget _buildMessageBubble(ChatMessage message) {', 'Widget _buildMessageInput() {'],
    'lib/screens/crop_image_page.dart': ['Widget _buildCropMode() {', 'Widget _buildPreviewMode() {', 'Widget _buildCropButtons() {', 'Widget _buildPreviewButtons() {'],
    'lib/screens/history_page.dart': ['Widget _buildEmptyState() {', 'Widget _buildErrorState() {'],
    'lib/screens/home_screen.dart': [],
    'lib/screens/login_screen.dart': ['Future<void> _showForgotPasswordDialog() async {'],
    'lib/screens/reset_password_screen.dart': ['Widget _buildVerifyingState() {', 'Widget _buildErrorState() {', 'Widget _buildResetForm() {', 'Widget _buildRequirement(String text) {']
}

for file_path, funcs in missing.items():
    if not os.path.exists(file_path):
        continue
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # ensure import
    if 'theme_notifier.dart' not in content:
        content = content.replace("import '../utils/apps_colors.dart';", "import '../utils/apps_colors.dart';\nimport '../utils/theme_notifier.dart';")
        
    # Replace all Theme.of(context).brightness == Brightness.dark with ThemeNotifier.instance.isDark
    content = content.replace("Theme.of(context).brightness == Brightness.dark", "ThemeNotifier.instance.isDark")
    content = content.replace("Theme.of(dialogContext).brightness == Brightness.dark", "ThemeNotifier.instance.isDark")

    for func in funcs:
        if func in content:
            content = content.replace(func, func + "\n    final isDark = ThemeNotifier.instance.isDark;")
        else:
            # Let's do a regex substitution since it might be formatted differently
            func_regex = re.escape(func).replace(r'\(', r'\s*\([^)]*\)\s*')
            match = re.search(func_regex, content)
            if match:
                content = content.replace(match.group(0), match.group(0) + "\n    final isDark = ThemeNotifier.instance.isDark;")
            else:
                print(f"Could not find exact match for {func} in {file_path}")

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
