#!/usr/bin/env python3
#
# Run by directly executing the file:
# ./codecollector.py

import argparse
import os
import fnmatch
import sys
import shutil
import time
from pathlib import Path
from datetime import datetime
import subprocess

# --- Configuration ---
# Mirrored from the original shell script
MAX_FILE_SIZE = 1_000_000  # 1MB

# Patterns for files to include in the tree but omit content
FILE_OMIT_CONTENT_PATTERNS = [
    # Terraform state and variables
    "*.tfstate", "*.tfstate.backup", "*.tfvars", "*.tfvars.json", "*.tfvars.yaml", "*.tfvars.yml",
    # Lock files
    "uv.lock", "poetry.lock", "package-lock.json",
    # Credentials and environment files
    "*.env", "*.env.yaml", "*.env.yml", "application.properties", "application.yml",
    "environment.properties", "environment.yml", "values.yaml", "values.yml",
    # Common binary file extensions
    "*.jar", "*.class", "*.zip", "*.png", "*.jpg", "*.jpeg", "*.gif", "*.svg",
    "*.webp", "*.mp4", "*.mp3", "*.mov", "*.pdf",
]

# Patterns for directories to always ignore during file scanning
FILE_NEVER_INCLUDE_IGNORE_DIRS = [
    "_build/", "deps/", ".git/", "node_modules/", ".venv/", "venv/", "env/",
    "ENV/", "__pycache__/", "dist/", "build/", ".next/", ".svelte-kit/",
    ".ruff_cache/", ".pytest_cache/", ".mypy_cache/", ".eslintcache/",
    ".wrangler/", ".vscode/", ".idea/", "test-logs/", "test-results/",
    "playwright-report/", "target/", "bin/", "obj/", "Debug/", "Release/",
    ".gradle/", "gradle/", "out/", "logs/", "tmp/", "temp/", "cache/",
    ".cache/", "coverage/", ".coverage/", ".nyc_output/", "htmlcov/",
    "mlruns/", "openspec/"
]

# Patterns for files to always ignore
FILE_NEVER_INCLUDE_IGNORE_FILES = [
    ".gitignore", ".codegiantignore", ".gcloudignore", ".cursorignore",
    ".dockerignore", ".aiderignore", ".extra_repo_ignores", ".git",
    ".DS_Store", "*.swp", "*.swo", "*.pyc", "*.pyo", "*$py.class",
    "!.aider.conf.yml", "!.aiderignore", ".aider*", "*.env", "*.env.yaml",
    "*_codegiant_*",
]

# --- Helper Functions ---

def is_binary(file_path: Path) -> bool:
    """Heuristic to check if a file is binary by looking for null bytes."""
    try:
        with open(file_path, 'rb') as f:
            return b'\0' in f.read(1024)
    except IOError:
        return False

def get_git_ignored_files(all_files: list[Path]) -> set[Path]:
    """
    Uses 'git check-ignore' to find which of the candidate files are ignored by git.
    This is much faster than calling git for each file individually.
    """
    if not shutil.which('git'):
        return set()
    try:
        repo_root_proc = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True, text=True, check=True, encoding='utf-8'
        )
        repo_root = Path(repo_root_proc.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return set()

    ignored_files = set()
    files_relative_to_root = []
    for p in all_files:
        try:
            relative_path = str(p.resolve().relative_to(repo_root.resolve()))
            files_relative_to_root.append(relative_path)
        except ValueError:
            # Skip files that are outside the git repository (e.g., symlinks pointing elsewhere)
            continue
    
    try:
        proc = subprocess.run(
            ['git', 'check-ignore', '--stdin', '-z'],
            input='\0'.join(files_relative_to_root),
            capture_output=True, text=True, cwd=repo_root, encoding='utf-8'
        )
        if proc.returncode == 0:
            ignored_relative_paths = proc.stdout.strip('\0').split('\0')
            for rel_path in filter(None, ignored_relative_paths):
                ignored_files.add(repo_root / rel_path)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return ignored_files

def parse_ignore_file(ignore_file_path: Path) -> list[str]:
    """Reads a .gitignore-style file and returns a list of patterns."""
    if not ignore_file_path.is_file():
        return []
    with open(ignore_file_path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f if line.strip() and not line.startswith('#')]

def parse_file_list(file_path: Path) -> list[Path]:
    """
    Reads a file containing a list of files to include (one per line).
    Ignores empty lines and comment lines starting with '#'.
    Returns a list of Path objects.
    """
    if not file_path.is_file():
        print(f"Warning: File list not found: {file_path}", file=sys.stderr)
        return []
    
    file_paths = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue
                
                # Convert to Path object and resolve relative to current working directory
                try:
                    path = Path(line)
                    if not path.is_absolute():
                        path = Path.cwd() / path
                    
                    # Check if file exists and warn if not
                    if not path.exists():
                        print(f"Warning: File from list does not exist (line {line_num}): {line}", file=sys.stderr)
                    else:
                        file_paths.append(path)
                except (OSError, ValueError) as e:
                    print(f"Warning: Invalid file path in list (line {line_num}): {line} - {e}", file=sys.stderr)
                    continue
    
    except (IOError, UnicodeDecodeError) as e:
        print(f"Error reading file list {file_path}: {e}", file=sys.stderr)
        return []
    
    return file_paths

def is_codegiant_ignored(relative_path: Path, codegiant_ignore_patterns: list[str]) -> tuple[bool, str]:
    """
    Checks if a file path is ignored by .codegiantignore patterns, with gitignore-like semantics.
    Handles negation. The last matching pattern wins.
    
    Args:
        relative_path: Path relative to the repository root
        codegiant_ignore_patterns: List of patterns from .codegiantignore
        
    Returns:
        (is_ignored, reason): Tuple indicating if file should be ignored and why
    """
    is_ignored = False
    last_match_reason = ""
    
    relative_path_str = str(relative_path)
    filename = relative_path.name
    
    for pattern_str in codegiant_ignore_patterns:
        # Handle negation patterns
        negated = pattern_str.startswith('!')
        if negated:
            pattern_str = pattern_str[1:]
        
        if not pattern_str.strip():
            continue
            
        matched = False
        
        # If pattern contains a slash, it's matched against the full relative path
        # and should respect directory boundaries
        if "/" in pattern_str:
            # Handle directory-only patterns (ending with /)
            if pattern_str.endswith('/'):
                # This is a directory pattern - check if the file is in this directory
                pattern_dir = pattern_str.rstrip('/')
                # Check if the file path starts with the pattern directory
                if relative_path_str.startswith(pattern_dir + '/'):
                    matched = True
            else:
                # Pattern with slash - must match from the beginning of the path
                # This ensures that "cg_test/*.txt" only matches files directly in cg_test/
                # and not in subdirectories like cg_test/subdir/file.txt
                if fnmatch.fnmatch(relative_path_str, pattern_str):
                    # Additional check: ensure no extra directory levels
                    pattern_parts = pattern_str.split('/')
                    path_parts = relative_path_str.split('/')
                    
                    # Pattern should match from the start and have same directory depth
                    if len(pattern_parts) == len(path_parts):
                        matched = True
        else:
            # Pattern without slash - match against filename only
            if fnmatch.fnmatch(filename, pattern_str):
                matched = True
        
        # Update ignore status based on match
        if matched:
            if negated:
                is_ignored = False
                last_match_reason = f"negated by pattern '!{pattern_str}'"
            else:
                is_ignored = True
                last_match_reason = f"matches .codegiantignore pattern '{pattern_str}'"
    
    return is_ignored, last_match_reason

def generate_tree_structure(file_paths: list[Path]) -> str:
    """Generates a tree-like string representation of the file paths."""
    if not file_paths:
        return "(No files to include in tree)"

    tree = {}
    for path in sorted(file_paths):
        current_level = tree
        for part in path.parts:
            current_level = current_level.setdefault(part, {})

    def build_tree_lines(d, prefix=""):
        lines = []
        items = sorted(d.keys())
        for i, name in enumerate(items):
            connector = "└── " if i == len(items) - 1 else "├── "
            lines.append(f"{prefix}{connector}{name}")
            if d[name]:
                extension = "    " if i == len(items) - 1 else "│   "
                lines.extend(build_tree_lines(d[name], prefix + extension))
        return lines

    return ".\n" + "\n".join(build_tree_lines(tree))

# --- Core Logic ---

def gather_files(args: argparse.Namespace) -> list[Path]:
    """
    Gathers and filters files based on the provided arguments, returning a sorted list of Paths.
    """
    start_time = time.time()
    print("Step 1: Gathering and filtering project files...", file=sys.stderr)

    if args.exclusive_files:
        print("  - Exclusive mode: Only specified files will be included.", file=sys.stderr)
        exclusive_paths = set()
        # Support comma-separated lists within each -i occurrence
        for pattern_group in args.exclusive_files:
            subpatterns = [p.strip() for p in pattern_group.split(',') if p.strip()]
            if not subpatterns:
                continue
            for subpattern in subpatterns:
                matched_files = list(Path.cwd().glob(subpattern))
                if not matched_files:
                    print(f"  - Warning: Pattern '{subpattern}' for -i didn't match any files.", file=sys.stderr)
                for f in matched_files:
                    if f.is_file():
                        exclusive_paths.add(f)
        return sorted(list(exclusive_paths))

    if args.file_list:
        print("  - File list mode: Only files from list will be included.", file=sys.stderr)
        print(f"  - Reading file list from: {args.file_list}", file=sys.stderr)
        file_list_paths = parse_file_list(args.file_list)
        if not file_list_paths:
            print("  - No valid files found in file list", file=sys.stderr)
            return []
        
        print(f"  - Found {len(file_list_paths)} files in list", file=sys.stderr)
        candidate_files = set()
        for file_path in file_list_paths:
            if file_path.is_file():
                candidate_files.add(file_path)
                if args.debug:
                    try:
                        relative_path = file_path.relative_to(Path.cwd())
                        print(f"  Adding from file list: {relative_path}", file=sys.stderr)
                    except ValueError:
                        print(f"  Adding from file list: {file_path}", file=sys.stderr)
        
        # Apply filtering to file list entries (but skip directory scanning)
        print("  - Applying filters to file list entries...", file=sys.stderr)
        # Continue to filtering section below instead of returning early
    else:
        # Enhanced directory filtering during os.walk to avoid collecting unnecessary files
        candidate_files = set()
        scan_dirs = args.directories or ['.']
        print(f"  - Scanning directories: {', '.join(scan_dirs)}", file=sys.stderr)

        scan_start = time.time()
        for directory in scan_dirs:
            start_path = Path(directory).resolve()
            if not start_path.is_dir():
                print(f"  - Warning: Directory not found, skipping: {directory}", file=sys.stderr)
                continue
            
            for root, dirs, files in os.walk(start_path, topdown=True):
                if not args.ignore_all_ignores:
                    # Enhanced directory filtering - more aggressive pruning
                    original_dir_count = len(dirs)
                    dirs[:] = [d for d in dirs if f"{d}/" not in FILE_NEVER_INCLUDE_IGNORE_DIRS]
                    
                    # Also filter out common patterns that might not be in the exact list
                    dirs[:] = [d for d in dirs if not any([
                        d.startswith('.') and d not in ['.github', '.vscode'],  # Hidden dirs except common ones
                        d.endswith('_cache'),  # Various cache directories
                        d.endswith('.tmp'),  # Temporary directories
                        'backup' in d.lower(),  # Backup directories
                        'temp' in d.lower() and len(d) < 10,  # Short temp-named dirs
                    ])]
                    
                    if args.debug and len(dirs) < original_dir_count:
                        pruned = original_dir_count - len(dirs)
                        print(f"  Pruned {pruned} directories from {root}", file=sys.stderr)
                
                for filename in files:
                    candidate_files.add(Path(root) / filename)

        scan_time = time.time() - scan_start
        print(f"  - Found {len(candidate_files)} initial file candidates in {scan_time:.2f}s", file=sys.stderr)

    # OPTIMIZATION: Apply cheap filters FIRST before expensive git check-ignore
    print("  - Applying early filters before git check...", file=sys.stderr)
    early_filter_start = time.time()
    
    pre_filtered_files = set()
    excluded_early = 0
    
    for file_path in candidate_files:
        # Skip symlinks that point outside the current directory
        if file_path.is_symlink():
            try:
                resolved_path = file_path.resolve()
                resolved_path.relative_to(Path.cwd().resolve())
            except (ValueError, OSError):
                excluded_early += 1
                if args.debug:
                    print(f"  Early exclude: {file_path} (symlink outside directory)", file=sys.stderr)
                continue
        
        # Apply cheap filters first
        excluded = False
        
        # Never-include file patterns (very fast)
        if (not args.ignore_all_ignores) and any(fnmatch.fnmatch(file_path.name, pat) for pat in FILE_NEVER_INCLUDE_IGNORE_FILES):
            excluded = True
            if args.debug:
                print(f"  Early exclude: {file_path} (never-include pattern)", file=sys.stderr)
        
        # Extension filtering (very fast)
        elif args.extensions and file_path.suffix[1:] not in args.extensions:
            excluded = True
            if args.debug:
                print(f"  Early exclude: {file_path} (extension not allowed)", file=sys.stderr)
        
        # Exclude files pattern (fast)
        elif args.exclude_files and any(fnmatch.fnmatch(file_path.name, pat) for pat in args.exclude_files):
            excluded = True
            if args.debug:
                print(f"  Early exclude: {file_path} (exclude pattern)", file=sys.stderr)
        
        # Exclude directories (fast)
        elif args.exclude_dirs and any(part in file_path.parts for part in args.exclude_dirs):
            excluded = True
            if args.debug:
                print(f"  Early exclude: {file_path} (excluded directory)", file=sys.stderr)
        
        if excluded:
            excluded_early += 1
        else:
            pre_filtered_files.add(file_path)
    
    early_filter_time = time.time() - early_filter_start
    print(f"  - Early filtering: {len(candidate_files)} → {len(pre_filtered_files)} files ({excluded_early} excluded) in {early_filter_time:.2f}s", file=sys.stderr)

    # Now apply the expensive operations on the reduced set
    codegiant_ignore = []
    if not args.ignore_all_ignores:
        codegiant_ignore = parse_ignore_file(Path.cwd() / '.codegiantignore')
    
    git_ignored = set()
    if not args.ignore_all_ignores:
        git_start = time.time()
        git_ignored = get_git_ignored_files(list(pre_filtered_files))
        git_time = time.time() - git_start
        print(f"  - Git ignore check on {len(pre_filtered_files)} files in {git_time:.2f}s", file=sys.stderr)
    else:
        print("  - Skipping git ignore check as --ignore-all-ignores was specified.", file=sys.stderr)
    
    # Final filtering pass
    final_files = set()
    final_filter_start = time.time()
    
    for file_path in pre_filtered_files:
        try:
            relative_path = file_path.relative_to(Path.cwd())
            relative_path_str = str(relative_path)
        except ValueError:
            relative_path = file_path
            relative_path_str = str(file_path)

        # Check remaining exclusion reasons
        excluded = False
        exclude_reason = ""
        
        # Check .codegiantignore patterns
        is_ignored, ignore_reason = is_codegiant_ignored(relative_path, codegiant_ignore)
        
        if file_path.resolve() in git_ignored:
            excluded = True
            exclude_reason = "git ignored"
        elif is_ignored:
            excluded = True
            exclude_reason = ignore_reason
        
        if excluded:
            if args.debug:
                print(f"  Final exclude: {relative_path_str} ({exclude_reason})", file=sys.stderr)
            continue
        
        if args.debug:
            print(f"  Including: {relative_path_str}", file=sys.stderr)
        final_files.add(file_path)

    final_filter_time = time.time() - final_filter_start
    print(f"  - Final filtering: {len(pre_filtered_files)} → {len(final_files)} files in {final_filter_time:.2f}s", file=sys.stderr)

    if args.always_add:
        print("  - Adding force-included files.", file=sys.stderr)
        for pattern in args.always_add:
            matched_files = list(Path.cwd().glob(pattern))
            if not matched_files:
                 print(f"  - Warning: Pattern '{pattern}' for -a didn't match any files.", file=sys.stderr)
            for f in matched_files:
                if f.is_file():
                    try:
                        relative_f = str(f.relative_to(Path.cwd()))
                    except ValueError:
                        relative_f = str(f)
                    print(f"  Force-including: {relative_f}", file=sys.stderr)
                    final_files.add(f)

    total_time = time.time() - start_time
    print(f"  - Final file count: {len(final_files)} (total processing: {total_time:.2f}s)", file=sys.stderr)
    if not final_files:
        print("Warning: No files found to include in context after all filters.", file=sys.stderr)
    return sorted(list(final_files))

def generate_context_file(args: argparse.Namespace, file_list: list[Path]):
    """Generates the final markdown context file."""
    output_dir = Path(".codegiant")
    output_dir.mkdir(exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    context_file = output_dir / f"{timestamp}_codegiant_context.md"
    
    print(f"\nStep 2: Generating context file: {context_file}", file=sys.stderr)
    relative_file_list = []
    for p in file_list:
        try:
            relative_file_list.append(p.relative_to(Path.cwd()))
        except ValueError:
            # Handle symlinks or paths outside current directory
            relative_file_list.append(p)

    with open(context_file, "w", encoding="utf-8") as f:
        f.write("# Directory Structure\n")
        f.write("_Includes files where the actual content might be omitted. This way the LLM can still use the file structure to understand the project._\n")
        f.write("```\n")
        f.write(generate_tree_structure(relative_file_list))
        f.write("\n```\n\n")

        if args.tree_only:
            print("  - Tree-only mode enabled, skipping file contents.", file=sys.stderr)
            return context_file

        f.write("# File Contents\n")
        if args.ignore_all_ignores:
            all_omit_patterns = args.omit_content or []
        else:
            all_omit_patterns = FILE_OMIT_CONTENT_PATTERNS + (args.omit_content or [])
        added, omitted = 0, 0

        for path in file_list:
            try:
                relative_path = path.relative_to(Path.cwd())
            except ValueError:
                # Handle symlinks or paths outside current directory
                relative_path = path
            f.write(f"\n## File: `{relative_path}`\n```\n")
            
            omit_reason = ""
            if any(fnmatch.fnmatch(str(relative_path), pat) or fnmatch.fnmatch(path.name, pat) for pat in all_omit_patterns):
                omit_reason = "matches an omit pattern"
            elif path.stat().st_size > MAX_FILE_SIZE:
                omit_reason = f"file size > {MAX_FILE_SIZE // 1024}KB"
            elif is_binary(path):
                omit_reason = "BINARY"

            if omit_reason:
                f.write(f"Content omitted due to reason: {omit_reason}\n")
                print(f"  Omitting content: {relative_path} ({omit_reason})", file=sys.stderr)
                omitted += 1
            else:
                try:
                    content = path.read_text(encoding="utf-8")
                    f.write(content)
                    # Ensure there's a newline before closing code fence
                    if content and not content.endswith('\n'):
                        f.write('\n')
                    print(f"  Adding content: {relative_path}", file=sys.stderr)
                    added += 1
                except (UnicodeDecodeError, IOError) as e:
                    f.write(f"[Error reading file: {e}]\n")
                    print(f"  Error reading: {relative_path} ({e})", file=sys.stderr)
                    omitted += 1
            f.write("```\n")
    
    print(f"  - Added content of {added} files.", file=sys.stderr)
    print(f"  - Omitted content of {omitted} files.", file=sys.stderr)
    return context_file

def ensure_codegiant_dir_setup(always_yes: bool):
    """Ensures the .codegiant directory exists and is in .gitignore."""
    output_dir = Path(".codegiant")
    gitignore_file = Path(".gitignore")
    if output_dir.is_dir():
        return

    print("\n================================================", file=sys.stderr)
    print(" =  Directory '.codegiant/' does not exist.", file=sys.stderr)
    print("================================================", file=sys.stderr)
    
    should_create = always_yes
    if not always_yes:
        try:
            reply = input(" Should I create '.codegiant/' and add it to '.gitignore'? (y/n) ").lower()
            should_create = reply.startswith('y')
        except (EOFError, KeyboardInterrupt):
            print("\nOperation cancelled.", file=sys.stderr)
            sys.exit(1)

    if should_create:
        output_dir.mkdir(exist_ok=True)
        if not gitignore_file.exists() or f"{output_dir.name}/" not in gitignore_file.read_text(encoding='utf-8'):
            with open(gitignore_file, "a", encoding='utf-8') as f:
                f.write(f"\n# Ignore Code Giant output directory\n{output_dir.name}/\n")
    else:
        print("\nUser declined. Exiting.", file=sys.stderr)
        sys.exit(1)

def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(description="Gathers project context into a single markdown file.", formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-e', '--extensions', type=lambda s: s.split(','), help="Comma-separated list of file extensions to include (e.g., 'js,py,md').")
    parser.add_argument('-d', '--directories', action='append', help="Directory to scan. Can be specified multiple times. Defaults to '.'")
    parser.add_argument('-l', '--file-list', type=Path, help="Path to file containing list of files to include exclusively (one per line). Can be combined with -a to add extra files.")
    parser.add_argument('-a', '--always-add', action='append', help="Glob pattern for files to always include. Can be specified multiple times.")
    parser.add_argument('-i', '--exclusive-files', action='append', help="Glob pattern for files to include exclusively. No other files will be considered.")
    parser.add_argument('-x', '--exclude-dirs', action='append', help="Directory name to exclude. Can be specified multiple times.")
    parser.add_argument('-X', '--exclude-files', action='append', help="Glob pattern for files to exclude. Can be specified multiple times.")
    parser.add_argument('-o', '--output-file', type=Path, help="Copy the generated context file to an additional file location.")
    parser.add_argument('-O', '--omit-content', action='append', help="Glob pattern for files to include in tree but omit content.")
    parser.add_argument('-T', '--tree-only', action='store_true', help="Only include the directory tree, not file contents.")
    parser.add_argument('-L', '--list-files-only', action='store_true', help="Only list the files that would be included, not the directory tree.")
    parser.add_argument('-y', '--yes', action='store_true', help="Skip prompt for .codegiant directory creation.")
    parser.add_argument('--debug', action='store_true', default=False, help="Enable debug output (default: False).")
    parser.add_argument('--ignore-all-ignores', action='store_true', help="Bypass gitignore, .codegiantignore, and hardcoded ignore patterns.")
    args = parser.parse_args()

    if args.exclusive_files and any([args.directories, args.extensions, args.always_add, args.file_list]):
        parser.error("Option -i/--exclusive-files cannot be used with -d, -e, -a, or -l.")
    
    if args.file_list and any([args.directories, args.extensions, args.exclusive_files]):
        parser.error("Option -l/--file-list cannot be used with -d, -e, or -i.")

    try:
        ensure_codegiant_dir_setup(args.yes)
        file_list = gather_files(args)

        if args.list_files_only:
            print(f"\n\nFile list with {len(file_list)} files (as -L was given - will stop after this):")
            for file in file_list:
                print(f"INCLUDED ABSOLUTE FILE: {file}")
            print("\n\n")
            sys.exit(0)

        context_file = generate_context_file(args, file_list)

        if args.output_file:
            # Check if source and destination are the same file
            try:
                if context_file.resolve() == args.output_file.resolve():
                    print(f"\n📋 Output file is the same as generated file, skipping copy: {args.output_file}", file=sys.stderr)
                else:
                    print(f"\n📋 Copying context file to: {args.output_file}", file=sys.stderr)
                    args.output_file.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(context_file, args.output_file)
                    print("  ✅ Successfully copied.", file=sys.stderr)
            except Exception as e:
                print(f"  ❌ Failed to copy: {e}", file=sys.stderr)

        print(f"\n✅ Context file generated: {context_file}")

    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()