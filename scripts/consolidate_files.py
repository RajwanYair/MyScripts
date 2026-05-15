import os
import json
import glob

# Configuration
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_FILES = {
    'requirements.txt': 'requirements.txt',
    'apt-packages.txt': 'apt-packages.txt',
    'PROJECT_SPEC_PROMPT.md': 'PROJECT_SPEC_PROMPT.md',
}
VSCODE_SETTINGS_NAME = 'settings.json'
VSCODE_DIR_NAME = '.vscode'

def find_files(root_dir, filename):
    """Find all files with a specific name in subdirectories."""
    matches = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Skip the root dir itself to avoid finding the output file as input immediately
        # (though we handle it in consolidation logic too)
        if dirpath == root_dir:
            # We still want to find files in root if they exist, but we need to be careful.
            # The user said "consolidate from all project... to this folder".
            # If we include the root file, we are merging it with others.
            pass
            
        if filename in filenames:
            matches.append(os.path.join(dirpath, filename))
    return matches

def find_vscode_settings(root_dir):
    """Find all settings.json files inside .vscode directories."""
    matches = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        if VSCODE_DIR_NAME in dirnames:
            vscode_path = os.path.join(dirpath, VSCODE_DIR_NAME)
            settings_path = os.path.join(vscode_path, VSCODE_SETTINGS_NAME)
            if os.path.exists(settings_path):
                matches.append(settings_path)
    return matches

def consolidate_text_lines(file_paths, output_path):
    """Consolidate text files by merging unique lines."""
    unique_lines = set()
    
    # Read existing output file if it exists to preserve its content
    if os.path.exists(output_path):
        try:
            with open(output_path, 'r', encoding='utf-8') as f:
                for line in f:
                    stripped = line.strip()
                    if stripped and not stripped.startswith('#'):
                        unique_lines.add(stripped)
        except Exception as e:
            print(f"Error reading existing {output_path}: {e}")

    for path in file_paths:
        if os.path.abspath(path) == os.path.abspath(output_path):
            continue # Skip the output file itself if found in search
            
        try:
            with open(path, 'r', encoding='utf-8') as f:
                for line in f:
                    stripped = line.strip()
                    if stripped and not stripped.startswith('#'):
                        unique_lines.add(stripped)
        except Exception as e:
            print(f"Error reading {path}: {e}")
            
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            for line in sorted(unique_lines):
                f.write(f"{line}\n")
        print(f"Consolidated {len(file_paths)} files into {output_path}")
    except Exception as e:
        print(f"Error writing to {output_path}: {e}")

def consolidate_markdown(file_paths, output_path):
    """Consolidate markdown files by appending content with headers."""
    content_blocks = []
    
    for path in file_paths:
        # Skip output file to avoid duplication
        if os.path.abspath(path) == os.path.abspath(output_path):
            continue

        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                rel_path = os.path.relpath(path, ROOT_DIR)
                header = f"\n\n# Source: {rel_path}\n\n"
                content_blocks.append(header + content)
        except Exception as e:
            print(f"Error reading {path}: {e}")
            
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            # Write a header
            f.write(f"# Consolidated Project Specs\nGenerated on {os.path.basename(ROOT_DIR)}\n")
            for block in content_blocks:
                f.write(block)
        print(f"Consolidated {len(content_blocks)} files into {output_path}")
    except Exception as e:
        print(f"Error writing to {output_path}: {e}")

def consolidate_json_settings(file_paths, output_path):
    """Consolidate JSON settings files."""
    merged_settings = {}
    
    # Read existing output if exists
    if os.path.exists(output_path):
        try:
            with open(output_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, dict):
                    merged_settings.update(data)
        except Exception as e:
            print(f"Error reading existing {output_path}: {e}")

    for path in file_paths:
        if os.path.abspath(path) == os.path.abspath(output_path):
            continue
            
        try:
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, dict):
                    merged_settings.update(data)
        except Exception as e:
            print(f"Error reading {path}: {e}")
            
    # Ensure .vscode directory exists for the output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(merged_settings, f, indent=4, sort_keys=True)
        print(f"Consolidated {len(file_paths)} settings files into {output_path}")
    except Exception as e:
        print(f"Error writing to {output_path}: {e}")

def main():
    print(f"Scanning {ROOT_DIR}...")
    
    # 1. Requirements.txt
    req_files = find_files(ROOT_DIR, 'requirements.txt')
    consolidate_text_lines(req_files, os.path.join(ROOT_DIR, 'requirements.txt'))
    
    # 2. Apt-packages.txt
    apt_files = find_files(ROOT_DIR, 'apt-packages.txt')
    consolidate_text_lines(apt_files, os.path.join(ROOT_DIR, 'apt-packages.txt'))
    
    # 3. PROJECT_SPEC_PROMPT.md
    spec_files = find_files(ROOT_DIR, 'PROJECT_SPEC_PROMPT.md')
    consolidate_markdown(spec_files, os.path.join(ROOT_DIR, 'PROJECT_SPEC_PROMPT.md'))
    
    # 4. VSCode Settings
    settings_files = find_vscode_settings(ROOT_DIR)
    vscode_output = os.path.join(ROOT_DIR, '.vscode', 'settings.json')
    consolidate_json_settings(settings_files, vscode_output)

if __name__ == "__main__":
    main()
