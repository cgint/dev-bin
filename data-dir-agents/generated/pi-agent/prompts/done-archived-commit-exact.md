---
description: Archive current openspec change and commit only touched files
---
Final review done by user.
Please archive the openspec change using the appropriate skill.
Whenever possible decide to "Do sync before archiving" to update main OpenSpec specs from this change, then archive.

After that commit exactly and only:
 - If we used openspec: The openspec change documents of the change that we were implementing in this session (including the archived copy under `openspec/changes/archive/YYYY-MM-DD-<name>/` with proposal, design, tasks, and delta spec)
 - The files touched in the process of implementing that change

The archived docs must be committed to git — they are the version-controlled change record (not just local workspace files). Other users cloning the repo need to see them.

Do not revert other files that might have changed in the meantime through concurrent code changes.
Do not commit any other files that we did not touch in this session.