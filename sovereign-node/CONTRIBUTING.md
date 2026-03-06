# Contributing to SovereignNode

Thank you for your interest in contributing to SovereignNode! This document provides guidelines for contributing.

## Ways to Contribute

- **Hardware compatibility** — Test on new hardware, submit tier configs and benchmark results
- **DePIN integrations** — Add new DePIN node containers and earning guides
- **Dashboard improvements** — UI/UX, new app integrations, API endpoints
- **Documentation** — Translations, guides, diagrams
- **Bug fixes** — Fix issues and improve reliability
- **Security audits** — Review code for vulnerabilities

## Development Setup

```bash
git clone https://github.com/WestCope/Olares---Freenode.git
cd Olares---Freenode/sovereign-node

# Dashboard (Python)
cd dashboard
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py

# Token (Rust/Anchor)
cd ../token
anchor build
anchor test
```

## Code Style

- **Python** (dashboard): PEP 8, use `black` for formatting
- **Bash scripts**: ShellCheck compliant, `set -euo pipefail` at top
- **Rust** (token): `rustfmt`, `clippy` clean
- **YAML** (Ansible/Docker): 2-space indent, descriptive names
- **Documentation**: Markdown, keep line length ≤ 120 chars

## Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes with tests
4. Run linters: `./scripts/lint.sh`
5. Submit a Pull Request with a clear description

## Security

For security vulnerabilities, please email security@sovereignnode.io (do NOT open public issues).

## Code of Conduct

Be respectful, inclusive, and constructive. We follow the [Contributor Covenant](https://www.contributor-covenant.org/).

## License

By contributing, you agree your contributions will be licensed under the MIT License.
