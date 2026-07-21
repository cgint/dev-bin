# Trivy — Dependency vulnerability scan

Scans lockfiles (`uv.lock`, `package-lock.json`, `mix.lock`, `pom.xml`, etc.) for known CVEs in dependencies.

## Usage

```
./precommit.sh
```

First run downloads ~100MiB vulnerability DB (cached in a Docker volume).

## Requires

- Docker (`docker info` must work)
