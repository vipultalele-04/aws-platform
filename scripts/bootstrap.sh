#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# bootstrap.sh — Run this ONCE to set up remote state
# Usage: ./scripts/bootstrap.sh
# ══════════════════════════════════════════════════════════════════
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}==============================${NC}"
echo -e "${YELLOW}  AWS Platform Bootstrap${NC}"
echo -e "${YELLOW}==============================${NC}"

# Check prerequisites
for cmd in terraform aws; do
  if ! command -v $cmd &>/dev/null; then
    echo -e "${RED}ERROR: $cmd not installed${NC}"
    exit 1
  fi
done

echo -e "${GREEN}Prerequisites OK${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
  echo -e "${RED}ERROR: AWS credentials not configured. Run: aws configure${NC}"
  exit 1
fi
echo -e "${GREEN}AWS credentials OK${NC}"
aws sts get-caller-identity --query 'Account' --output text | xargs -I{} echo "Account: {}"

# Create S3 + DynamoDB for remote state
echo -e "\n${YELLOW}Step 1: Creating S3 bucket + DynamoDB for Terraform state...${NC}"
cd terraform/backend
terraform init -input=false
terraform apply -auto-approve

# Grab bucket name from output
BUCKET=$(terraform output -raw state_bucket_name)
echo -e "${GREEN}State bucket: ${BUCKET}${NC}"

# Patch backend.tf with the real bucket name
cd ../..
sed -i "s/REPLACE_WITH_YOUR_BUCKET_NAME/${BUCKET}/" terraform/main.tf
echo -e "${GREEN}Updated terraform/main.tf with bucket: ${BUCKET}${NC}"

# Re-init main Terraform with remote backend
echo -e "\n${YELLOW}Step 2: Initialising Terraform with remote state...${NC}"
cd terraform
terraform init -input=false
echo -e "${GREEN}Terraform initialised with S3 remote state${NC}"

echo -e "\n${GREEN}==============================${NC}"
echo -e "${GREEN}  Bootstrap complete!${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit terraform/terraform.tfvars (set key_name + db_password)"
echo "  2. Add GitHub Secrets (see README.md)"
echo "  3. git add . && git commit -m 'init' && git push"
