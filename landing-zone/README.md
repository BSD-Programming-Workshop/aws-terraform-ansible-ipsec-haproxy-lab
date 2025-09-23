# Landing Zone (Index)

This directory contains the Terraform code for the landing zone implementation. This README intentionally serves as a lightweight index to avoid duplicating end-to-end guidance from the repository root.

For the complete workflow (bootstrap, foundation, MFA, security, workloads, troubleshooting), see the canonical guide in the repo root:

- ../../README.md

## What lives here

```
landing-zone/
├── phase1-foundation/     # AWS Organizations, Control Tower, accounts
├── phase2-security/       # Cross-account roles, MFA policies, groups
├── modules/
│   └── unix-workload/     # Reusable OS-agnostic infra (FreeBSD and/or RHEL)
└── environments/
    ├── dev/               # Unix Dev account deployments
    ├── staging/           # Unix Staging account deployments
    └── prod/              # Unix Prod account deployments
```

## Start here

- Phase 1 (foundation): `phase1-foundation/`
- Phase 2 (security): `phase2-security/`
- Workloads by environment: `environments/` (see `environments/README.md`)
- Reusable module details: `modules/unix-workload/`

## Notes

- Terminology: this repo uses "Unix Dev/Staging/Prod" naming consistently (OS-agnostic). The unix-workload module supports FreeBSD by default and optionally RHEL via a custom AMI ID.
- For emails, MFA workflow, and common AWS gotchas (including Control Tower IAM propagation delay), refer to the root `README.md`.
