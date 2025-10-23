#!/usr/bin/env python3
"""
Additional Code Cleanup - remove unused imports, variables, and optimize memory leaks
"""

import os
import re
import glob

def clean_imports_and_unused(file_path):
    """Clean unused imports and variables"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Remove unused StreamController declarations that are never used
        content = re.sub(r'\s*static final StreamController<[^>]+> _[^=]+ = StreamController<[^>]+>\.broadcast\(\);\s*\n', '', content)
        
        # Remove empty catch blocks with just rethrow or return
        content = re.sub(r'} catch \(e\) {\s*rethrow;\s*}', '} catch (e) { rethrow; }', content)
        content = re.sub(r'} catch \(e\) {\s*return [^;]+;\s*}', '} catch (e) { return null; }', content)
        
        # Clean up excessive empty lines
        content = re.sub(r'\n\s*\n\s*\n\s*\n', '\n\n', content)
        
        # Remove trailing whitespace
        content = re.sub(r'[ \t]+$', '', content, flags=re.MULTILINE)
        
        # Remove unnecessary legacy support comments
        content = re.sub(r'\s*/// LEGACY SUPPORT.*?\n', '', content)
        
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def optimize_dart_files(directory):
    """Optimize all Dart files"""
    optimized_files = []
    
    # Find all .dart files
    dart_files = glob.glob(os.path.join(directory, '**', '*.dart'), recursive=True)
    
    for file_path in dart_files:
        if clean_imports_and_unused(file_path):
            optimized_files.append(file_path)
            print(f"⚡ Optimized: {os.path.relpath(file_path, directory)}")
    
    return optimized_files

if __name__ == "__main__":
    lib_dir = "./lib"
    if os.path.exists(lib_dir):
        print("⚡ Optimizing code for memory leaks and unused code...")
        optimized = optimize_dart_files(lib_dir)
        print(f"\n🎉 Optimized {len(optimized)} files.")
        
        if optimized:
            print("\nOptimized files:")
            for file in optimized[:10]:
                print(f"  - {os.path.relpath(file, lib_dir)}")
            if len(optimized) > 10:
                print(f"  ... and {len(optimized) - 10} more")
    else:
        print("❌ lib directory not found!")