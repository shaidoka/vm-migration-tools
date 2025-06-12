# OpenStack Credentials Template
# Copy this file and modify with your actual credentials
# Then source it before running the migration scripts:
# source openstack-credentials.sh

# Authentication URL (replace with your OpenStack endpoint)
export OS_AUTH_URL="https://your-openstack-endpoint:5000/v3"

# Project Information
export OS_PROJECT_ID="your-project-id"
export OS_PROJECT_NAME="your-project-name"
export OS_PROJECT_DOMAIN_ID="default"

# User Information
export OS_USERNAME="your-username"
export OS_PASSWORD="your-password"
export OS_USER_DOMAIN_NAME="Default"

# Region and Interface
export OS_REGION_NAME="your-region"
export OS_INTERFACE="public"

# API Versions
export OS_IDENTITY_API_VERSION=3
export OS_COMPUTE_API_VERSION=2.1

# Optional: Disable SSL verification (only for testing)
# export OS_INSECURE=1

# Test your credentials after sourcing:
# openstack token issue
