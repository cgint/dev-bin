# Agentic Development Tools & Orchestration

This repository is a collection of CLI tools, automation scripts, and configuration templates designed to optimize a developer's workflow when working with AI coding assistants (like Gemini, GitHub Copilot, Cursor, and pi-agent).

Its primary purpose is to act as a **central nervous system** for "Agentic Coding"—providing the glue that connects your local codebase to Large Language Models.

## What is this for?

### 1. AI Agent Management

The core of the project lives in `data-dir-agents`. It provides a single source of truth for:

* **System Instructions:** Standardized "rules of engagement" for AI agents.
* **Agent Skills:** Reusable tool descriptions and guidance (e.g., how an agent should use D2 for diagrams or how it should search your codebase).
* **Propagation:** A system to generate and deploy these instructions to all your tools simultaneously, ensuring your AI assistants behave consistently across different interfaces.

### 2. Context Collection

To get good results from an LLM, you need to provide the right context. This repo includes specialized tools (`codecollector.py`, `codegiant.py`) that bundle your project structure and relevant files into a format that AI models can easily "digest" and act upon.

### 3. Developer Productivity CLI

A suite of shell scripts to automate frequent development tasks:

* **Search:** Quick, filtered searching across your entire development workspace.
* **Web Knowledge:** Grounded web search via Gemini to get technical answers without leaving the terminal.
* **Project Management:** Scripts for cloning worker projects, upgrading Node dependencies, and managing Neo4j databases.
* **Configuration Rollouts:** Tools to keep your `.gitignore`, `.cursorrules`, and other config files in sync across dozens of different projects.

### 4. Specialized Setup

Included are bootstrap scripts (like `pi-setup.sh`) to quickly configure a new machine with the company-standard AI environment, including Node.js prerequisites and global agent settings.

## High-Level Workflow

1. **Configure:** Define how you want your AI to behave in the `definitions` directory.
2. **Propagate:** Deploy those rules to your various AI tools.
3. **Execute:** Use the provided CLI tools to gather context and interact with LLMs to solve coding tasks efficiently.

## Core Philosophy

* **Code over Strings:** Don't manually copy-paste prompts; use the propagation system.
* **Context is King:** Use the collectors to give the AI the full picture.
* **CLI First:** Everything is designed to be triggered quickly from a terminal.