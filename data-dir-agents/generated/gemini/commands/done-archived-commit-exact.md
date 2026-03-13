---
description: Archive current openspec change and commit only touched files
---
Final review done by user.
Please archive the openspec change using the appropriate skill.
Whenever possible decide to "Do sync before archiving" to update main OpenSpec specs from this change, then archive.

After that commit exactly and only:
 - If we used openspec: The openspec change documents of the change that we were implementing in this session
 - The files touched in the process of implementing that change

Do not revert other files that might have changed in the meantime through concurrent code changes.
Do not commit any other files that we did not touch in this session.