# Cloud Daisy Portfolio Website

Cloud Daisy's personal portfolio site, hosted on AWS, secured by Cloudflare, and deployed with Terraform.

**Live site:** [cloud-daisy.com](https://cloud-daisy.com)

## Overview

This repo contains a static portfolio website and the infrastructure-as-code used to deploy it. The site is served from Amazon S3 through CloudFront, with Cloudflare sitting in front as the DNS provider and edge security layer (replacing AWS WAF to keep costs down). Deployments are managed through Terraform and automated with GitHub Actions.

## Architecture

```
Visitor
  │
  ▼
Cloudflare (DNS, proxied)
  • Managed WAF ruleset
  • Bot Fight Mode
  • Rate limiting (20 req/10s per IP)
  • Adds X-Origin-Verify header
  │
  ▼
Amazon CloudFront
  • CloudFront Function checks X-Origin-Verify header
    → blocks any request that bypasses Cloudflare (403)
  • ACM certificate (cloud-daisy.com, www.cloud-daisy.com)
  │
  ▼
Amazon S3 (private bucket, Origin Access Control only)
```

## Tech stack

- **Hosting:** Amazon S3 (static site) + Amazon CloudFront (CDN)
- **TLS:** AWS Certificate Manager, validated via Cloudflare DNS
- **DNS & edge security:** Cloudflare (proxied DNS, WAF, bot protection, rate limiting)
- **Origin protection:** CloudFront Function + Cloudflare Transform Rule (shared-secret header)
- **Infrastructure as code:** Terraform (S3 backend for state)
- **CI/CD:** GitHub Actions, authenticated to AWS via OIDC (no long-lived AWS keys)

## Repository structure

```
.
├── index.html, services.html, portfolio.html, ...   # site pages
├── assets/                                           # images, badges, logo
├── style.css
├── script.js
├── terraform/
│   ├── backend.tf          # S3 backend config for Terraform state
│   ├── providers.tf        # AWS provider config (us-east-1, aliased for ACM)
│   ├── main.tf              # S3 bucket, ACM cert, CloudFront, origin-verify function
│   ├── variables.tf         # variable declarations
│   ├── terraform.tfvars     # local secret values (gitignored, not in repo)
│   └── .gitignore           # excludes state, secrets, .terraform/
└── .github/workflows/
    └── deploy.yml            # GitHub Actions CI/CD pipeline
```

## Infrastructure

Provisioned via Terraform in the `terraform/` directory:

- Private S3 bucket for the site, with public access blocked
- CloudFront distribution with Origin Access Control (OAC) — S3 is never exposed directly
- ACM certificate for `cloud-daisy.com` and `www.cloud-daisy.com`, DNS-validated
- CloudFront Function that checks every request for a secret `X-Origin-Verify` header, rejecting anything that didn't come through Cloudflare

Terraform state is stored remotely in a dedicated S3 bucket, with state locking enabled.

## Security

Since this project skips AWS WAF to save cost, protection is layered instead:

- **Cloudflare** sits in front of everything (proxied DNS), providing a managed WAF ruleset, bot protection, and a per-IP rate limit — all on the Free plan
- **Origin-verify header:** Cloudflare attaches a secret header to every request it forwards; a CloudFront Function checks for it and returns 403 to anything that skips Cloudflare and hits the CloudFront domain directly
- **S3** is private and only reachable through CloudFront via Origin Access Control

## CI/CD

Deployments run through GitHub Actions (`.github/workflows/deploy.yml`), authenticated to AWS using OpenID Connect — no AWS access keys are stored in GitHub.

- **On push to `main`:** the `plan` job runs automatically, showing what Terraform would change
- **Manual trigger (`workflow_dispatch`):** runs `plan` followed by `apply`, deploying the change

To deploy a change:
1. Push code to `main` (this runs `plan` automatically — review the output in the Actions tab)
2. Go to **Actions → Deploy Cloud Daisy → Run workflow** to trigger `apply`

## Local development

Site files are plain HTML/CSS/JS — open `index.html` directly, or serve the folder with any static file server.

To work with the infrastructure locally:

```bash
cd terraform
terraform init
terraform plan
```

A `terraform.tfvars` file with an `origin_verify_secret` value is required locally (not committed — see `.gitignore`). The same secret must also be set as the `ORIGIN_VERIFY_SECRET` GitHub Actions secret, and configured as the header value in Cloudflare's origin-verify Transform Rule.

## Notes

- The old-style `.html` URLs (e.g. `/services.html`) are current behavior; clean URLs are a planned improvement.
- Full build and deployment write-up: coming soon on Hashnode.

---

Built by [Cloud Daisy](https://cloud-daisy.com)
