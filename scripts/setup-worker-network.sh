#!/usr/bin/env bash
#
# setup-worker-network.sh - Create Docker network for filtered worker containers
#
# Creates a custom Docker bridge network (yak-workers) that will be used
# with iptables filtering to restrict container network access to only
# whitelisted LLM API endpoints.
#
set -euo pipefail

NETWORK_NAME="yak-workers"
NETWORK_SUBNET="172.20.0.0/16"
NETWORK_GATEWAY="172.20.0.1"
BRIDGE_NAME="br-yak-workers"

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed or not in PATH" >&2
    exit 1
fi

# Create yak-workers network if it doesn't exist
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "$NETWORK_NAME network already exists"
    docker network inspect "$NETWORK_NAME" --format '{{range .IPAM.Config}}Subnet: {{.Subnet}}{{end}}'
else
    echo "Creating $NETWORK_NAME network with subnet $NETWORK_SUBNET..."
    docker network create \
        --driver bridge \
        --subnet "$NETWORK_SUBNET" \
        --gateway "$NETWORK_GATEWAY" \
        --opt "com.docker.network.bridge.name=$BRIDGE_NAME" \
        "$NETWORK_NAME"
    echo "Created $NETWORK_NAME Docker network"
    echo "Subnet: $NETWORK_SUBNET"
    echo "Gateway: $NETWORK_GATEWAY"
fi

echo ""
echo "Network setup complete. Run setup-worker-firewall.sh to configure filtering."