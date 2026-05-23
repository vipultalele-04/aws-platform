# AWS Platform — Complete DevOps Setup

## Architecture

```
Internet
    │
    ▼
External ALB  (internet-facing, public subnets)
    │  port 80/443
    ▼
Public EC2 ×2  (nginx reverse proxy)
    │  port 80
    ▼
Internal ALB  (private subnets, no public IP)
    │  port 8080
    ▼
Private EC2 ×2  (app server)
    │  port 3306
    ▼
RDS Primary + Read Replica  (db subnets, isolated)
```

## Repository structure

```
aws-platform/
├── .github/
│   └── workflows/
│       ├── 01-terraform-plan.yml   # PR → plan + PR comment
│       ├── 02-deploy.yml           # merge → apply + ansible + smoke test
│       └── 03-destroy.yml          # manual only, requires confirmation
│
├── terraform/
│   ├── backend/
│   │   └── main.tf                 # bootstrap S3 + DynamoDB (run once)
│   ├── main.tf                     # provider + S3 backend config
│   ├── variables.tf
│   ├── vpc.tf                      # VPC, IGW, NAT, route tables
│   ├── subnets.tf                  # 6 subnets across 3 tiers
│   ├── security_groups.tf          # 5 SGs — strict access chain
│   ├── alb.tf                      # external + internal ALB
│   ├── ec2.tf                      # 2 public + 2 private EC2
│   ├── rds.tf                      # primary RDS + read replica
│   ├── outputs.tf                  # IPs/endpoints used by Ansible
│   └── terraform.tfvars            # YOUR values (gitignored)
│
├── ansible/
│   ├── ansible.cfg
│   ├── playbook.yml                # main entry point for project
│   ├── inventory/
│   │   └── hosts.ini               # auto-built by GitHub Actions
│   ├── group_vars/
│   │   └── all.yml
│   └── roles/
│       ├── common/                 # OS hardening + CloudWatch agent
│       ├── webserver/              # nginx on public EC2
│       └── appserver/              # app server on private EC2
│
├── scripts/
│   └── bootstrap.sh                # one-click remote state setup
│
├── .gitignore
└── README.md
```

---

## STEP-BY-STEP SETUP GUIDE

---

### STEP 1 — Prerequisites (install on your machine)

```bash
# Install Terraform
curl -fsSL https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip -o tf.zip
unzip tf.zip && sudo mv terraform /usr/local/bin/
terraform --version   # should print 1.7.0

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
aws --version

# Install Ansible (for local runs)
pip3 install ansible
ansible --version

# Install Git
sudo apt-get install git   # Ubuntu/Debian
```

---

### STEP 2 — AWS account setup

#### 2a. Create an IAM user for automation

```
AWS Console → IAM → Users → Create user
Name: github-actions-deploy
Access type: Programmatic access (Access key)
```

Attach these policies:
- `AmazonEC2FullAccess`
- `AmazonRDSFullAccess`
- `ElasticLoadBalancingFullAccess`
- `AmazonVPCFullAccess`
- `AmazonS3FullAccess`
- `AmazonDynamoDBFullAccess`
- `CloudWatchFullAccess`

**Save the Access Key ID and Secret Access Key — you'll need them in Step 5.**

#### 2b. Configure AWS CLI locally

```bash
aws configure
# AWS Access Key ID:     paste your key
# AWS Secret Access Key: paste your secret
# Default region:        us-east-1
# Output format:         json

# Verify it works
aws sts get-caller-identity
```

#### 2c. Create an EC2 Key Pair

```
AWS Console → EC2 → Key Pairs → Create key pair
Name:   aws-platform-key
Format: .pem
```

Download the `.pem` file and move it somewhere safe:
```bash
mv ~/Downloads/aws-platform-key.pem ~/.ssh/
chmod 400 ~/.ssh/aws-platform-key.pem
```

---

### STEP 3 — Clone and configure the repo

```bash
# Clone
git clone https://github.com/YOUR-ORG/aws-platform.git
cd aws-platform

# Edit terraform.tfvars with YOUR values
vim terraform/terraform.tfvars
```

Update these values:
```hcl
key_name    = "aws-platform-key"      # name of key pair from step 2c
db_password = "YourStr0ngP@ssword!"   # strong password for RDS
```

---

### STEP 4 — Bootstrap remote state (run once)

This creates the S3 bucket and DynamoDB table that store Terraform state.

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

The script will:
1. Create S3 bucket + DynamoDB table
2. Automatically update `terraform/main.tf` with the bucket name
3. Re-initialise Terraform pointing to the remote state

After this, **Terraform state is stored in S3** — never locally.

---

### STEP 5 — Add GitHub Secrets

Go to: **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**

Add ALL of these:

| Secret name | Where to get it |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user from Step 2a |
| `AWS_SECRET_ACCESS_KEY` | IAM user from Step 2a |
| `TF_VAR_KEY_NAME` | `aws-platform-key` (name from Step 2c) |
| `TF_VAR_DB_PASSWORD` | Same password as terraform.tfvars |
| `EC2_SSH_PRIVATE_KEY` | Contents of your `.pem` file (see below) |
| `SLACK_WEBHOOK_URL` | Optional — Slack incoming webhook |

To get the contents of your `.pem` file:
```bash
cat ~/.ssh/aws-platform-key.pem
# Copy the entire output including -----BEGIN RSA PRIVATE KEY----- lines
```

---

### STEP 6 — Push to GitHub and trigger the pipeline

```bash
# Initial commit
git add .
git commit -m "initial: complete aws platform setup"
git push origin main
```

**This push to main triggers `02-deploy.yml` automatically.**

Watch it run at: `github.com/YOUR-ORG/aws-platform/actions`

---

### STEP 7 — Day-to-day workflow (after initial setup)

```bash
# 1. Create a feature branch
git checkout -b feature/increase-instance-size

# 2. Make your change
vim terraform/variables.tf   # e.g. change instance_type to t3.small

# 3. Commit and push
git add .
git commit -m "increase EC2 instance size"
git push origin feature/increase-instance-size

# 4. Open a Pull Request on GitHub
#    → GitHub Actions runs terraform plan automatically
#    → Plan output appears as a comment on the PR

# 5. Review the plan comment, get approval, merge
#    → GitHub Actions runs terraform apply + ansible automatically
#    → Smoke test runs
#    → Slack notification sent
```

---

### STEP 8 — Verify the deployment

After the pipeline finishes (check the Actions tab):

```bash
# Get the external ALB DNS from Terraform outputs
cd terraform
terraform output external_alb_dns

# Test the full chain
curl http://<external_alb_dns>/health
# Expected: HTTP 200 OK
```

#### SSH access chain:
```bash
# Step 1: SSH into public EC2 (with agent forwarding)
ssh -i ~/.ssh/aws-platform-key.pem -A ec2-user@<public_ec2_ip>

# Step 2: From public EC2, jump to private EC2
ssh ec2-user@<private_ec2_ip>

# Step 3: From private EC2, connect to RDS
mysql -h <rds_endpoint> -P 3306 -u admin -p
```

#### CloudWatch logs:
```
AWS Console → CloudWatch → Log groups → /aws/ec2/
```

---

### STEP 9 — Destroy everything (when done)

**GitHub Actions UI → Actions → "3 · Destroy" → Run workflow**

Type `destroy` in the confirmation field.

Or locally:
```bash
cd terraform
terraform destroy -var-file="terraform.tfvars"
```

---

## Security group access chain (summary)

```
Internet (0.0.0.0/0)
    ↓ 80/443
sg-alb-external
    ↓ 80/443 — source: sg-alb-external only
sg-public-ec2
    ↓ 80 — source: sg-public-ec2 only
sg-alb-internal
    ↓ 8080 — source: sg-alb-internal only
sg-private-ec2
    ↓ 3306 — source: sg-private-ec2 only
sg-rds
```

No tier can be accessed directly — each layer only accepts traffic from the layer immediately above it.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `terraform init` fails | Check AWS credentials: `aws sts get-caller-identity` |
| Pipeline fails at plan | Check GitHub Secrets are all set correctly |
| Ansible SSH timeout | EC2 may still be booting — re-run workflow |
| Health check 504 | nginx → internal ALB may need 2-3 minutes to warm up |
| RDS connection refused | Check private EC2 SG allows 3306 from sg-private-ec2 |
