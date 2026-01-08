# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |
| < latest | :x:               |

We only provide security updates for the latest release. Please keep your installation up to date.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: **security@lovelesslabs.com**

Include as much of the following information as possible:

- Type of issue (e.g., command injection, credential exposure, etc.)
- Full paths of source file(s) related to the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue

### What to Expect

- **Acknowledgment**: Within 48 hours of your report
- **Status Update**: Within 7 days with an assessment
- **Resolution**: We aim to release a fix within 30 days for confirmed vulnerabilities

### Disclosure Policy

- We will coordinate disclosure timing with you
- We will credit you in the release notes (unless you prefer to remain anonymous)
- We ask that you give us reasonable time to address the issue before public disclosure

## Security Considerations

### Credentials and Secrets

gh-coda interacts with sensitive systems:

- **GitHub API**: Uses `gh` CLI authentication (your GitHub token)
- **1Password**: Uses `op` CLI for secrets (requires 1Password authentication)

**Best practices:**

- Never commit `.gh-coda` files containing secrets
- Use 1Password references instead of plaintext secrets
- Review config files before sharing or committing

### Token Scopes

gh-coda requires certain GitHub token scopes. Use the minimum necessary:

```bash
# Basic repo settings only
gh auth login --scopes repo

# With Dependabot features
gh auth login --scopes repo,security_events

# With org secrets
gh auth login --scopes repo,security_events,admin:org
```

### Config File Permissions

Config files may contain sensitive information. Ensure appropriate permissions:

```bash
chmod 600 ~/.config/gh-coda/*.conf
```

## Known Security Considerations

- Config files are parsed as YAML and converted to JSON via `yj` and `jq`
- Shell commands are constructed from config values - we sanitize inputs but exercise caution with untrusted configs
- The `set-secrets` command transmits secrets from 1Password to GitHub - ensure you trust both endpoints
