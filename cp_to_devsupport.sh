#!/bin/bash

echo
echo Copying files needed to use codegiant to "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/bin/"
echo
cp codegiant.py codecollector.py "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/bin/"


echo
echo Copying scripts needed to use agentic tools to "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/bin/"
echo
cp gem.sh webs.sh d2to.sh plantuml.sh asks.sh browsershot.sh agent-browser-cleanup.sh pi-setup.sh "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/bin/"


echo
echo Copying data-dir-agents to "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/data-dir-agents/"
echo
rsync -av \
  --exclude='my-tools-toolbox' \
  --exclude='codebase-search' \
  --exclude='read-code-structure' \
  --exclude='agents_files_cp.sh' \
  --delete-after \
  data-dir-agents/ \
  "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/agentic-coding/data-dir-agents/"

cp agents_files_cp.sh "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/agentic-coding/"
cp data-dir-agents/README.md "$HOME/dev/Workspace-java8/devsupport-solution/workspace-tools/agentic-coding/"


echo
echo Now open the project in IntelliJ IDEA
echo
idea "$HOME/dev/Workspace-java8/devsupport-solution"