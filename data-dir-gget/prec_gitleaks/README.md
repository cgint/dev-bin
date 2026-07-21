# Gitleaks — Secrets scan

Scans git history for hardcoded credentials (API keys, tokens, private keys).

## Usage

```
./precommit.sh
```

## Configuration

Create `.gitleaks.toml` in your project root to exclude known false positives:

```toml
[allowlist]
  paths = [
    '''path/to/training_data.py''',
  ]
```

## Requires

- Docker (`docker info` must work)
