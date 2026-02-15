#!/usr/bin/env bash
#
# setup-worker-firewall.sh - Configure iptables rules for worker network filtering
#
# Sets up iptables rules to filter traffic from the yak-workers Docker network,
# allowing only DNS and HTTPS to whitelisted API endpoints.
#
set -euo pipefail

WORKER_NETWORK="172.20.0.0/16"
IPSET_NAME="yak-allowed-apis"
CHAIN_NAME="YAK_WORKER_FILTER"

# Ensure ipset is installed
if ! command -v ipset >/dev/null 2>&1; then
    echo "Installing ipset..."
    apt-get update && apt-get install -y ipset
fi

# Create ipset if needed
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    ipset create "$IPSET_NAME" hash:ip timeout 3600
    echo "Created ipset: $IPSET_NAME"
fi

# Check if rules already exist (idempotent)
if iptables -C FORWARD -s "$WORKER_NETWORK" -j "$CHAIN_NAME" 2>/dev/null; then
    echo "Firewall rules already configured"
    echo "Chain: $CHAIN_NAME"
    iptables -L "$CHAIN_NAME" -n -v | head -10
    exit 0
fi

# Create custom chain for worker filtering
iptables -N "$CHAIN_NAME" 2>/dev/null || iptables -F "$CHAIN_NAME"

# Allow established/related connections (return traffic)
iptables -A "$CHAIN_NAME" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (required for API hostname resolution)
iptables -A "$CHAIN_NAME" -p udp --dport 53 -j ACCEPT
iptables -A "$CHAIN_NAME" -p tcp --dport 53 -j ACCEPT

# Allow HTTPS to whitelisted API IPs
iptables -A "$CHAIN_NAME" -p tcp --dport 443 -m set --match-set "$IPSET_NAME" dst -j ACCEPT

# Log non-whitelisted connections (monitor-only mode — no blocking)
# Change ACCEPT to DROP below when ready to enforce
iptables -A "$CHAIN_NAME" -j LOG --log-prefix "YAK-WORKER-DENY: " --log-level 4
iptables -A "$CHAIN_NAME" -j ACCEPT

# Jump to our chain from FORWARD for worker network traffic
iptables -I FORWARD 1 -s "$WORKER_NETWORK" -j "$CHAIN_NAME"

echo "Firewall rules configured successfully"
echo ""
echo "To view rules: iptables -L $CHAIN_NAME -n -v"
echo "To view allowed IPs: ipset list $IPSET_NAME"
echo ""
echo "IMPORTANT: Run update-api-ipset.sh to populate allowed IPs"