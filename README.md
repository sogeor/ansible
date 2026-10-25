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

Server addresses are not stored here: they come from the encrypted state of `sogeor/tofu`. Keys and tokens are in `*.sops.yaml`, encrypted for the maintainers' age key and the CI age key.

Servers accept SSH only on port 822, only for the user `ansible`, only with a certificate signed by the Sogeor user CA or with an offline break-glass key. Root login and passwords are disabled. Maintainer certificates are valid for 30 days, the CI certificate for 90 days.

Deployments run only from `master` in the `production` environment; pull requests, including those from forks, never get its secrets.

## Background

| Layer | What | Where |
| --- | --- | --- |
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
| --- | --- |
| `inventory/tofu.yml` | inventory plugin: hosts, groups, `ansible_host`, `ansible_port`, `wg_address` |
| `inventory/group_vars/all/main.yml` | SSH connection, versions, cluster addressing, firewall, WireGuard peers, backups |
| `inventory/group_vars/all/secrets.sops.yaml` | cluster SOPS key, etcd encryption key |
| `inventory/host_vars/<host>.yml` | disk UUIDs, interfaces, host overrides |
| `inventory/host_vars/<host>.sops.yaml` | WireGuard key, S3 keys, tokens |
| `files/user-data.yaml`, `scripts/render-user-data.sh` | cloud-init template and its renderer |
| `files/bootstrap.sh` | the same first-boot state for servers installed without user data |
| `site.yml` / `status.yml` | Kubernetes nodes / status page server |
| `.github/workflows/deploy.yml` | automatic deployment |

## Install

Requirements on the workstation:

- `ansible-core` with `ansible-lint` in the same environment:
  `pipx install ansible-core && pipx inject ansible-core ansible-lint --include-apps`;
- SOPS and age with a maintainer key, `SOPS_AGE_KEY_FILE` exported;
- OpenTofu and a clone of [sogeor/tofu](https://github.com/sogeor/tofu) next to this repository (the inventory reads `../tofu/servers`);
- the SSH key `~/.ssh/sogeor_ansible` with a valid certificate `~/.ssh/sogeor_ansible-cert.pub`, loaded into `ssh-agent`;
- the Bitwarden CLI, for `scripts/render-user-data.sh`.

The inventory runs `tofu show`, so the shell needs the same environment as `sogeor/tofu`:

| Variable | Value |
| --- | --- |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | S3 credentials for the OpenTofu state (read-only is enough) |
| `TF_VAR_state_passphrase` | OpenTofu state encryption passphrase |

Load them however you prefer, for example with a [direnv](https://direnv.net/) `.envrc` in the folder that contains both clones; it applies to every repository below it and must not be committed.

```bash
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph
ansible all -m ping
```

## Usage

**Deployment is automatic.** A push to `master` here, or a successful `tofu apply` in `sogeor/tofu`, runs the `deploy` workflow: it reads the inventory from the tofu state and applies `site.yml` and `status.yml`. A check-mode run can be started by hand: Actions → deploy → Run workflow → check.

Bootstrap a new server:

```bash
scripts/render-user-data.sh <host>       # cloud-init for the provider form; copied to the clipboard
# or, for a server that is already installed:
ssh root@<IP> "bash -s -- <host> '<user CA public key>' '<break-glass public key>'" < files/bootstrap.sh
```

Then add the server to `sogeor/tofu` (`servers/servers.sops.yaml`); after the pull request is merged and the plan is applied, the deploy workflow configures it.

Run the playbooks by hand:

```bash
ansible-playbook site.yml --check --diff           # dry run
ansible-playbook site.yml --diff                   # apply
ansible-playbook site.yml --tags firewall          # one role
ansible-playbook site.yml --limit odin             # one host
ansible-playbook status.yml --diff                 # status page server
```

Edit secrets with `sops inventory/host_vars/<host>.sops.yaml`.

## Development

```bash
pre-commit install          # gitleaks, linters, secret checks
pre-commit run --all-files
ansible-lint
ansible-playbook -i localhost, --syntax-check site.yml
ansible-playbook -i localhost, --syntax-check status.yml
```

Roles are tested with [Molecule](https://ansible.readthedocs.io/projects/molecule/) in Docker: `molecule/default` runs `site.yml` and `status.yml` against containers that mirror the servers (`odin` on Debian 13, `zelda` on Ubuntu 24.04, both with systemd), checks that a second run changes nothing and runs `verify.yml`. It needs Docker and no secrets:

```bash
pipx inject ansible-core molecule "molecule-plugins[docker]" --include-apps
ansible-galaxy collection install community.docker
molecule test
```

Pull requests run the same checks in CI without secrets or access to the servers. Versions in `group_vars` carry `# renovate:` comments and are updated by Renovate.

## Maintainers

[Sogeor maintainers](https://github.com/orgs/sogeor/teams/maintainers)

## Contributing

Issues and pull requests are welcome. Read the [contributing guidelines](https://github.com/sogeor/.github/blob/HEAD/CONTRIBUTING.md) and the [Code of Conduct](https://github.com/sogeor/.github/blob/HEAD/CODE_OF_CONDUCT.md). Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/); first-time contributors sign the [CLA](https://github.com/sogeor/.github/blob/HEAD/CLA.md).

Merged changes are deployed to the servers automatically, so every pull request is reviewed with that in mind.

## License

© 2026 Georgii Sopin. [Sogeor License 1.0](LICENSE) (English and Russian; the Russian version prevails) — you may read the code and contribute, but not copy, redistribute or reuse it.
