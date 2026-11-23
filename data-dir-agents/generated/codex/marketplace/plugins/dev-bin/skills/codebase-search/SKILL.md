---
name: codebase-search
description: Codebase search toolbox (colgrep, asks.sh, dev_find.sh, dev_file_find.sh, ctags_symbol_map.py, ripgrep/rg)
---
# CLI Tools Catalog
# Run <tool> -h for detailed usage information

- colgrep             Semantic grep - find code by meaning/natural language ::: Example: colgrep -y "function that handles user authentication" ::: use -c for full content
- asks.sh             Query documentation using BM25 search and generate answers by topic ::: Example: asks.sh my-sourcecode "Where doe we use Gemini Live API" ::: list of topics by simply running asks.sh
- dev_find.sh         Search file contents across ~/dev for a query (ripgrep with smart defaults) ::: Example: dev_find.sh "gemini-2.0-" py toml ts js java
- dev_file_find.sh    Search for filenames containing a pattern across ~/dev ::: Example: dev_file_find.sh "config"
- ctags_symbol_map.py Extract class/function/method symbols using Universal Ctags ::: Example: ctags_symbol_map.py .

