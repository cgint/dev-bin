---
name: read-code-structure
description: Extract symbol map / structure (ctags_symbol_map.py, Universal Ctags)
---

# Code Structure & Symbol Extraction

This skill helps you understand the structure of your codebase by extracting symbols (classes, functions, methods) using ctags.

## Tool

**ctags_symbol_map.py** - Extract class/function/method symbols using Universal Ctags, organized as a searchable symbol map.

## Usage

```bash
ctags_symbol_map.py <project-directory>
```

## Examples

```bash
# Analyze current project
ctags_symbol_map.py .

# Analyze specific directory
ctags_symbol_map.py ~/dev/your-project

# Use with pip: ctags_symbol_map.py <path>
ctags_symbol_map.py . | less
```

## Why Use This Skill

- **Quick navigation**: Find all functions, classes, and methods in your codebase
- **Understand architecture**: See the module/class structure at a glance
- **Navigate efficiently**: Jump to specific symbols or discover where something is defined
- **Code comprehension**: Better understand larger codebases

## How It Works

This tool runs Universal Ctags to scan your code and creates a structured symbol map. It's especially useful for:
- Finding where a function or class is defined
- Locating all methods in a particular class
- Understanding the organization of your project
- Jumping to specific code locations

## Output

The tool produces a comprehensive list of symbols organized by:
- **Classes**: Class names and their members
- **Functions**: Top-level functions and their signatures
- **Methods**: Methods defined within classes
- **Modules**: Main modules and their organization

## Best Practices

- **Run in project root**: Execute from the root of your project for the most complete view
- **Focus on navigation**: Use this to quickly find where things are, not to understand the full implementation initially
- **Combine with reading**: Use symbol map to understand structure, then read specific files for details
- **Save for reference**: The output format is perfect for saving into a README or documentation file
- **Update regularly**: Keep the symbol map updated as your codebase changes

## Tips

- First argument should be a directory path
- Command works across multiple languages (Python, JavaScript, Java, etc. - any ctags can parse)
- Use with `| grep` or text editors that support symbol navigation for targeted searches
- The output is perfect for static analysis and code documentation generation

## Integration

This tool can be paired with:
- **Code reading**: Use symbol map to understand structure, then read specific files
- **Documentation**: Export results to markdown for team documentation
- **Refactoring**: Identify all references to a class or function before refactoring
- **Onboarding**: New team members can quickly understand code structure