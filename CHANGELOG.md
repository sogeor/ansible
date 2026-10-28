# Changelog

## [1.1.0](https://github.com/sogeor/ansible/compare/v1.0.3...v1.1.0) (2026-10-28)


### Added

* add base role for Debian and Ubuntu servers ([#32](https://github.com/sogeor/ansible/issues/32)) ([e1fdf36](https://github.com/sogeor/ansible/commit/e1fdf36397bbcdc5364e0b519808f07b8efb7065))
* add firewall role with automatic rollback ([#33](https://github.com/sogeor/ansible/issues/33)) ([2588ca2](https://github.com/sogeor/ansible/commit/2588ca2499a5fcde95564f346a0e6d3da130050b))
* add status_vps role for status.sogeor.com ([#36](https://github.com/sogeor/ansible/issues/36)) ([30ab638](https://github.com/sogeor/ansible/commit/30ab6383db57fac77ffcc62548d193082479dc6e))
* add wireguard role for admin access ([#35](https://github.com/sogeor/ansible/issues/35)) ([79e9527](https://github.com/sogeor/ansible/commit/79e95270fad52d70949be6fa252a271fb5cd1efa))


### Changed

* update github/codeql-action digest to 9b32540 ([#42](https://github.com/sogeor/ansible/issues/42)) ([0346cdf](https://github.com/sogeor/ansible/commit/0346cdfc8e764516bc72ef72444dbce6663db852))
* update pre-commit hook davidanson/markdownlint-cli2 to v0.24.0 ([#41](https://github.com/sogeor/ansible/issues/41)) ([72f17c7](https://github.com/sogeor/ansible/commit/72f17c76bad027f2ffddfa3e2a868b32a931f7c2))
* update sogeor/workflows action to v1.3.0 ([#27](https://github.com/sogeor/ansible/issues/27)) ([a142cb6](https://github.com/sogeor/ansible/commit/a142cb66ed1521b701571ee836bea14bc4452bf7))
* update sogeor/workflows action to v1.3.1 ([#29](https://github.com/sogeor/ansible/issues/29)) ([4d535af](https://github.com/sogeor/ansible/commit/4d535af4badc41b6a9580aa279256df65546cd3d))
* update sogeor/workflows action to v1.3.2 ([#30](https://github.com/sogeor/ansible/issues/30)) ([d132108](https://github.com/sogeor/ansible/commit/d13210872a7c0e87e5cc65397452328c269b065e))
* update sogeor/workflows action to v1.3.3 ([#37](https://github.com/sogeor/ansible/issues/37)) ([8e0ec27](https://github.com/sogeor/ansible/commit/8e0ec27937737c4e68e18976e708487001af3b5f))


### Fixed

* deploy the new Telegram bot token of the status page ([#39](https://github.com/sogeor/ansible/issues/39)) ([81eae7e](https://github.com/sogeor/ansible/commit/81eae7eb9e096f3fb4d3cac3a6d7d8a8ee1bae3d))
* exempt the admin tunnel from the SSH rate limit ([#40](https://github.com/sogeor/ansible/issues/40)) ([09ffbf2](https://github.com/sogeor/ansible/commit/09ffbf2ae449af593aa6348ffb1ea268af29a652))
* reset the SSH connection only when the firewall changes ([#34](https://github.com/sogeor/ansible/issues/34)) ([dedac49](https://github.com/sogeor/ansible/commit/dedac49638dc55faf6808901b3b17327c3a2597a))
* rotate the Telegram bot token of the status page ([#38](https://github.com/sogeor/ansible/issues/38)) ([3126e87](https://github.com/sogeor/ansible/commit/3126e879f2c6752f4bd805f0f73266bbccd028b0))

## [1.0.3](https://github.com/sogeor/ansible/compare/v1.0.2...v1.0.3) (2026-10-25)


### Changed

* update sogeor/workflows action to v1.2.0 ([#23](https://github.com/sogeor/ansible/issues/23)) ([513ff59](https://github.com/sogeor/ansible/commit/513ff59707ad296ba39f6298aeb45bab9ee91f04))

## [1.0.2](https://github.com/sogeor/ansible/compare/v1.0.1...v1.0.2) (2026-10-24)


### Changed

* update actions/checkout action to v7 ([#15](https://github.com/sogeor/ansible/issues/15)) ([62b3694](https://github.com/sogeor/ansible/commit/62b369431de89b8de6a85b33ed7f429915e42e1c))
* update actions/create-github-app-token action to v3 ([#16](https://github.com/sogeor/ansible/issues/16)) ([4f4a384](https://github.com/sogeor/ansible/commit/4f4a3849d8509a00e586b08780528af6073bc525))
* update github/codeql-action action to v4 ([#17](https://github.com/sogeor/ansible/issues/17)) ([f76e2a4](https://github.com/sogeor/ansible/commit/f76e2a4551e875af3d172748baf6e94b743873e0))
* update pre-commit (non-major) ([#14](https://github.com/sogeor/ansible/issues/14)) ([36c2729](https://github.com/sogeor/ansible/commit/36c2729b900c166a4f49a22bfb5d5a7f7eed841a))
* update pre-commit hook fsfe/reuse-tool to v6 ([#18](https://github.com/sogeor/ansible/issues/18)) ([212dbc9](https://github.com/sogeor/ansible/commit/212dbc91b86151c46f2bca6701d6efe7d7788cf6))
* update pre-commit hook pre-commit/pre-commit-hooks to v6 ([#19](https://github.com/sogeor/ansible/issues/19)) ([6c43dba](https://github.com/sogeor/ansible/commit/6c43dba6afc80c7b16f8cafeec739e16c5fe6e9e))

## [1.0.1](https://github.com/sogeor/ansible/compare/v1.0.0...v1.0.1) (2026-10-24)


### Changed

* update dependency etcd-io/etcd to v3.7.2 ([#11](https://github.com/sogeor/ansible/issues/11)) ([1a813f3](https://github.com/sogeor/ansible/commit/1a813f39e82722bc198088be01e8e42570db88f8))
* update ossf/scorecard-action action to v2.5.0 ([#12](https://github.com/sogeor/ansible/issues/12)) ([ef94acd](https://github.com/sogeor/ansible/commit/ef94acd03ff8c76c565c3c3a4edac832e8d18832))

## 1.0.0 (2026-10-24)


### Added

* add inventory, bootstrap, playbook skeleton and automatic deploy ([d52455b](https://github.com/sogeor/ansible/commit/d52455b9bd75c62853d6395836523e44115ceb36))

## Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

This file is generated by [release-please](https://github.com/googleapis/release-please) from [Conventional Commits](https://www.conventionalcommits.org/). Do not edit released sections by hand; unreleased changes are collected in the open release pull request.
