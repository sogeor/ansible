# ansible

[![CI](https://github.com/sogeor/ansible/actions/workflows/lint.yml/badge.svg)](https://github.com/sogeor/ansible/actions/workflows/lint.yml)
[![Release](https://img.shields.io/github/v/release/sogeor/ansible?sort=semver)](https://github.com/sogeor/ansible/releases)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/sogeor/ansible/badge)](https://scorecard.dev/viewer/?uri=github.com/sogeor/ansible)
[![License: source-available](https://img.shields.io/badge/license-source--available-informational)](LICENSE)

> Ansible playbooks for Sogeor servers: bootstrap, OS hardening, WireGuard, kubeadm, Cilium and Flux, backups, status page

Configures every Sogeor server from a clean OS to a working state: disks and boot, firewall, WireGuard, CRI-O and kubeadm, the first install of Cilium and Flux, etcd backups, and the status page server. Which servers exist comes from [sogeor/tofu](https://github.com/sogeor/tofu); what runs inside the cluster lives in [sogeor/fleet](https://github.com/sogeor/fleet).

## Table of Contents

- [Security](#security)
- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [Development](#development)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Security

Report vulnerabilities privately as described in the [security policy](https://github.com/sogeor/.github/blob/HEAD/SECURITY.md). Secrets in this repository are encrypted with SOPS; never commit them in plain text.

Server addresses are not stored here: they come from the encrypted state of `sogeor/tofu`. Keys and tokens are in `*.sops.yaml`, encrypted with the maintainers' age key.

Servers accept SSH only on port 822, only for the user `ansible`, only with a certificate signed by the Sogeor user CA (valid for 30 days) or with an offline break-glass key. Root login and passwords are disabled.

## Background

| Layer | What | Where |
|---|---|---|
| 0 | first boot: user `ansible`, SSH certificates, port 822, firewall | `files/user-data.yaml` (cloud-init) or `files/bootstrap.sh` (installed servers) |
| 1 | OS: disks, EFI, firewall, WireGuard, hardening, CRI-O, backups | roles, `site.yml` |
| 2 | cluster start: kubeadm, Gateway API CRDs, Cilium, Flux | roles, `site.yml` |
| — | status page server (Gatus) | `status.yml` |

```text
sogeor/tofu (servers stack, encrypted state)
        │  cloud.terraform.terraform_provider
        ▼
inventory/tofu.yml + group_vars + host_vars (SOPS) ──▶ ansible-playbook ──▶ servers
```

| Path | Contents |
|---|---|
| `inventory/tofu.yml` | inventory plugin: hosts, groups, `ansible_host`, `ansible_port`, `wg_address` |
| `inventory/group_vars/all/main.yml` | versions, cluster addressing, firewall, WireGuard peers, backups |
| `inventory/group_vars/all/secrets.sops.yaml` | etcd encryption key, cluster SOPS key |
| `inventory/host_vars/<host>.yml` | disk UUIDs, interfaces |
| `inventory/host_vars/<host>.sops.yaml` | WireGuard key, S3 keys, tokens |
| `files/user-data.yaml`, `scripts/render-user-data.sh` | cloud-init template and its renderer (keys from Bitwarden) |
| `files/bootstrap.sh` | the same first-boot state for servers installed without user data |
| `site.yml` / `status.yml` | Kubernetes nodes / status page server |

## Install

Requirements on the workstation:

- `ansible-core` and `ansible-lint` (`pipx install ansible-core ansible-lint`);
- SOPS and age with a maintainer key, `SOPS_AGE_KEY_FILE` exported;
- a clone of [sogeor/tofu](https://github.com/sogeor/tofu) next to this repository, OpenTofu and its environment (S3 credentials, state passphrase).

```bash
ansible-galaxy collection install -r requirements.yml
ln -s ../tofu/.envrc .envrc && direnv allow     # same variables as sogeor/tofu
ansible-inventory --graph
```

## Usage

Bootstrap a new server:

```bash
scripts/render-user-data.sh <host>       # cloud-init for the provider form; copied to the clipboard
# or, for a server that is already installed:
ssh root@<IP> "bash -s -- <host> '<user CA public key>' '<break-glass public key>'" < files/bootstrap.sh
```

Then add the server to `sogeor/tofu` (`servers/servers.sops.yaml`) and run the playbooks:

```bash
ansible-playbook site.yml --check --diff           # dry run
ansible-playbook site.yml --diff                   # apply
ansible-playbook site.yml --tags firewall          # one role
ansible-playbook site.yml --limit odin             # one host
ansible-playbook status.yml --diff                 # status page server
ansible-playbook site.yml -e ansible_port=22       # first run after an OS reinstall
```

Edit secrets with `sops inventory/host_vars/<host>.sops.yaml`.

## Development

```bash
pre-commit install          # gitleaks, linters, secret checks
pre-commit run --all-files
ansible-lint
ansible-playbook site.yml --syntax-check
```

Versions in `group_vars` carry `# renovate:` comments and are updated by Renovate.

## Maintainers

[Sogeor maintainers](https://github.com/orgs/sogeor/teams/maintainers)

## Contributing

Issues and pull requests are welcome. Read the [contributing guidelines](https://github.com/sogeor/.github/blob/HEAD/CONTRIBUTING.md) and the [Code of Conduct](https://github.com/sogeor/.github/blob/HEAD/CODE_OF_CONDUCT.md). Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/); first-time contributors sign the [CLA](https://github.com/sogeor/.github/blob/HEAD/CLA.md).

Playbooks are applied by maintainers only: CI has no access to the servers or the secrets.

## License

© 2026 Georgii Sopin. [Sogeor License 1.0](LICENSE) (English and Russian; the Russian version prevails) — you may read the code and contribute, but not copy, redistribute or reuse it.
