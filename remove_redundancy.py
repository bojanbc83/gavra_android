#!/usr/bin/env python3
"""
Remove Redundant SimplifiedDailyCheckInService and replace with direct DailyCheckInService calls
"""

import os
import re
import glob

def replace_simplified_calls(file_path):
    """Replace SimplifiedDailyCheckInService calls with DailyCheckInService"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Replace imports
        content = re.sub(
            r"import '../services/simplified_daily_checkin.dart';", 
            "import '../services/daily_checkin_service.dart';", 
            content
        )
        content = re.sub(
            r"import '.*?simplified_daily_checkin.dart';", 
            "import '../services/daily_checkin_service.dart';", 
            content
        )
        
        # Replace class references
        content = re.sub(
            r'SimplifiedDailyCheckInService\.', 
            'DailyCheckInService.', 
            content
        )
        
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def process_dart_files(directory):
    """Process all Dart files to remove SimplifiedDailyCheckInService"""
    changed_files = []
    
    # Find all .dart files
    dart_files = glob.glob(os.path.join(directory, '**', '*.dart'), recursive=True)
    
    for file_path in dart_files:
        # Skip the SimplifiedDailyCheckInService file itself - we'll delete it
        if 'simplified_daily_checkin.dart' in file_path:
            continue
            
        if replace_simplified_calls(file_path):
            changed_files.append(file_path)
            print(f"✅ Updated: {os.path.relpath(file_path, directory)}")
    
    return changed_files

if __name__ == "__main__":
    lib_dir = "./lib"
    if os.path.exists(lib_dir):
        print("🔄 Removing SimplifiedDailyCheckInService redundancy...")
        changed = process_dart_files(lib_dir)
        print(f"\n🎉 Updated {len(changed)} files.")
        
        # Show which files were changed
        if changed:
            print("\nChanged files:")
            for file in changed[:10]:
                print(f"  - {os.path.relpath(file, lib_dir)}")
            if len(changed) > 10:
                print(f"  ... and {len(changed) - 10} more")
        
        print("\n📝 Next step: Delete lib/services/simplified_daily_checkin.dart manually")
    else:
        print("❌ lib directory not found!")