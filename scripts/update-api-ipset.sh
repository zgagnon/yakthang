#!/usr/bin/env bash
#
# update-api-ipset.sh - Update allowed API IPs from DNS
#
# Resolves LLM API domains and adds their IPs to the ipset for iptables filtering.
# Should be run periodically (e.g., via cron) to handle CDN IP changes.
#
set -euo pipefail

IPSET_NAME="yak-allowed-apis"

# Allowed API domains (LLM providers)
DOMAINS=(
    "api.anthropic.com"
    "api.openai.com"
    "models.dev"
    "generativelanguage.googleapis.com"
    "opencode.ai"
)

# Ensure ipset is available
if ! command -v ipset >/dev/null 2>&1; then
    echo "Error: ipset not installed" >&2
    exit 1
fi

# Create ipset if it doesn't exist
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    ipset create "$IPSET_NAME" hash:ip timeout 3600
    echo "Created ipset: $IPSET_NAME"
fi

# Function to add IPs from domain to ipset
add_domain_ips() {
    local domain="$1"
    echo "Resolving $domain..."

    # Get IPv4 addresses
    dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | while read -r ip; do
        ipset add "$IPSET_NAME" "$ip" -exist 2>/dev/null || true
        echo "  Added $ip"
    done
}

# Add all allowed API domains
for domain in "${DOMAINS[@]}"; do
    add_domain_ips "$domain"
done

echo ""
echo "ipset updated successfully"
echo ""
echo "Current entries:"
ipset list "$IPSET_NAME" | head -25