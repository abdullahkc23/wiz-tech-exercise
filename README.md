# wiz-tech-exercise
# Wiz Tech Exercise – Terraform Infrastructure

This repo contains infrastructure as code to deploy:

- A public VPC
- One EC2 instance (MongoDB)
- A public S3 bucket for backups
- Automated provisioning via GitHub Actions

## Deploy Steps

1. Fork this repo or clone it
2. Add your AWS credentials to GitHub secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Push to main → triggers GitHub Actions
4. View outputs in Terraform Cloud or workflow logs
k
