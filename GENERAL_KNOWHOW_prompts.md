# Prompts

## README - tone and purpose

**@README.md** change to a simpler and down to earch tone - no need for e.g. "strategic shallow-ness" .

The readme should help people to quickly get an idea and not to read marketing blahblah

**Example:**

```bash
codegiant.sh -y -F -t "update readme if necessary - add a description of what this codebase enables the user to do and what it's high level purpose is - use simple and down to earch tone - The readme should help people to quickly get an idea and not to read marketing blahblah" \
 -o README_update_suggestion.md \
 && gem.sh flash -y -i "Update README.md in case there are suggestions to do so in README_update_suggestion.md" \
 && rm README_update_suggestion.md
```