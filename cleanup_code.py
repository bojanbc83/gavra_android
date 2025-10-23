#!/usr/bin/env python3
"""
Code Cleanup Script - automatski čisti debug komentare i optimizuje kod
"""

import os
import re
import glob

def clean_debug_comments(file_path):
    """Uklanja debug komentare iz fajla"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Ukloni "Debug logging removed for production" linije
        content = re.sub(r'\s*// Debug logging removed for production\n?', '', content)
        content = re.sub(r'\s*# Debug logging removed for production\n?', '', content)
        
        # Ukloni prazne debug blokove
        content = re.sub(r'\s*} catch \(e\) {\s*// Debug logging removed for production\s*}\s*', ' } catch (e) { /* ignored */ }', content)
        
        # Ukloni duplikate praznih linija
        content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
        
        # Ukloni trailing whitespace
        content = re.sub(r'[ \t]+$', '', content, flags=re.MULTILINE)
        
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def clean_dart_files(directory):
    """Čisti sve Dart fajlove u direktorijumu"""
    cleaned_files = []
    
    # Pronađi sve .dart fajlove
    dart_files = glob.glob(os.path.join(directory, '**', '*.dart'), recursive=True)
    
    for file_path in dart_files:
        if clean_debug_comments(file_path):
            cleaned_files.append(file_path)
            print(f"✅ Cleaned: {os.path.relpath(file_path, directory)}")
    
    return cleaned_files

if __name__ == "__main__":
    lib_dir = "./lib"
    if os.path.exists(lib_dir):
        print("🧹 Starting code cleanup...")
        cleaned = clean_dart_files(lib_dir)
        print(f"\n🎉 Cleanup complete! Cleaned {len(cleaned)} files.")
        
        if cleaned:
            print("\nCleaned files:")
            for file in cleaned[:10]:  # Show first 10
                print(f"  - {os.path.relpath(file, lib_dir)}")
            if len(cleaned) > 10:
                print(f"  ... and {len(cleaned) - 10} more")
    else:
        print("❌ lib directory not found!")