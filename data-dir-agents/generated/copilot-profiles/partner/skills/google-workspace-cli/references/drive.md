# Google Drive CLI Reference (`gws drive`)

Core patterns for Google Drive operations using `gws`.

## Examples

```bash
# List files (exact params vary; check schema/help)
gws drive files list --params '{"pageSize": 10}'

# Fetch a single file resource
gws drive files get --params '{"fileId": "..."}'

# Inspect what a method expects
gws schema drive.files.list --resolve-refs
```
