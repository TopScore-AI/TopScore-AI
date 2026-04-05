import os
import re

parts_dir = 'lib/tutor_client/parts'

for filename in os.listdir(parts_dir):
    if filename.endswith('.dart'):
        filepath = os.path.join(parts_dir, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Change part of
        content = content.replace("part of '../chat_screen.dart';", "part of '../chat_controller.dart';")
        
        # Change extension target
        content = re.sub(r'extension (\w+) on _ChatScreenState', r'extension \1 on ChatController', content)
        
        # Replace provider reads
        content = content.replace('Provider.of<AuthProvider>(context, listen: false)', 'context.read<AuthProvider>()')
        content = content.replace('Provider.of<SettingsProvider>(context, listen: false)', 'context.read<SettingsProvider>()')
        content = content.replace('Provider.of<AiTutorHistoryProvider>(context, listen: false)', 'context.read<AiTutorHistoryProvider>()')
        content = content.replace('Provider.of<TutorConnectionProvider>(context, listen: false)', 'context.read<TutorConnectionProvider>()')
        
        # setState rewrite using multiline regex to handle different forms
        content = re.sub(r'setState\(\(\)\s*\{([^}]*)\}\);', r'\1\n    notifyListeners();', content, flags=re.MULTILINE)
        content = re.sub(r'setState\(\s*\(\)\s*=>\s*(.*?)\s*\);', r'\1;\n    notifyListeners();', content)
        
        # Temporarily comment out 'widget.' access since fields are moved to controller
        content = content.replace('widget.', '/*widget.*/')

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

print("Part files refactored.")
