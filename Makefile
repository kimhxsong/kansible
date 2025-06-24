# Makefile for managing the Kubernetes cluster
# Simplified Structure
.PHONY: help all up down destroy status cluster reset validate test deploy-test ssh-master ssh-worker1 ssh-worker2 ssh-worker3 logs download-iso

# Default settings
VAGRANT_MACHINES = k8s-master k8s-worker1 k8s-worker2 k8s-worker3
ANSIBLE_INVENTORY = ansible/inventory.ini
ANSIBLE_PLAYBOOK_CONFIGURE = ansible/configure-cluster.yml
ANSIBLE_PLAYBOOK_RESET = ansible/reset-cluster.yml
ISO_FILE = ubuntu-24.04.2-live-server-arm64.iso
ISO_URL = https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-arm64.iso

# Default target
all: cluster

# Help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Setup:"
	@echo "  download-iso - Downloads the required Ubuntu ISO image."
	@echo ""
	@echo "Main Targets:"
	@echo "  all          - (Default) Creates VMs and configures the Kubernetes cluster."
	@echo "  cluster      - Configures the Kubernetes cluster on existing VMs."
	@echo "  destroy      - Destroys all VMs and cleans the environment."
	@echo "  up           - Creates and starts all VMs."
	@echo "  down         - Stops all VMs."
	@echo ""
	@echo "Cluster Management:"
	@echo "  reset        - Resets the Kubernetes cluster to a clean state."
	@echo "  validate     - Validates the status of the cluster nodes and system pods."
	@echo "  test         - Deploys a test application and validates it."
	@echo ""
	@echo "Maintenance:"
	@echo "  status       - Shows the status of the Vagrant VMs."
	@echo "  logs         - Shows the latest kubelet logs from the master node."
	@echo "  ssh-master   - SSH into the master node."
	@echo "  ssh-worker[1-3] - SSH into a specific worker node."


# --- Setup ---
download-iso:
	@if [ ! -f "$(ISO_FILE)" ]; then \
		echo "⬇️  Downloading $(ISO_FILE)..."; \
		curl -L -o $(ISO_FILE) $(ISO_URL); \
		echo "✅  Download complete."; \
	else \
		echo "✅  $(ISO_FILE) already exists."; \
	fi


# --- VM Lifecycle ---

# Create and start all VMs
up:
	@echo "🚀 Creating and starting all VMs..."
	vagrant up
	@echo "✅ All VMs are up and running."

# Stop all VMs
down:
	@echo "🔄 Stopping all VMs..."
	vagrant halt
	@echo "✅ All VMs have been stopped."

# Destroy all VMs and clean up
destroy:
	@echo "🧹 Destroying all VMs..."
	vagrant destroy -f
	@echo "✅ Environment cleaned."

# Check VM status
status:
	@echo "📊 VM Status:"
	vagrant status


# --- Kubernetes Workflow ---

# Configure Kubernetes cluster
cluster: up
	@echo "🎯 Configuring Kubernetes cluster..."
	@echo "⏳ Waiting for SSH connections..."
	@for machine in $(VAGRANT_MACHINES); do \
		echo "  - Checking connection to $$machine..."; \
		timeout 180 sh -c 'until vagrant ssh $$machine -c "echo Connected" >/dev/null 2>&1; do sleep 5; done' || \
		(echo "❌ SSH connection to $$machine failed." && exit 1); \
	done
	@echo "✅ SSH connections established."
	@echo "🔧 Running Ansible playbook..."
	ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_CONFIGURE)
	@echo "✅ Cluster configuration complete."

# Reset cluster
reset:
	@echo "🔄 Resetting the Kubernetes cluster..."
	ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_RESET)
	@echo "✅ Cluster reset complete."

# Validate cluster status
validate:
	@echo "🔍 Validating cluster status..."
	@vagrant ssh k8s-master -c "kubectl get nodes -o wide"
	@echo ""
	@vagrant ssh k8s-master -c "kubectl get pods -A"

# --- Testing ---

# Deploy a test application
deploy-test:
	@echo "🚀 Deploying NGINX test application..."
	@vagrant ssh k8s-master -c "kubectl create deployment nginx-test --image=nginx --replicas=3" || echo "Deployment might already exist."
	@vagrant ssh k8s-master -c "kubectl expose deployment nginx-test --port=80 --type=NodePort" || echo "Service might already exist."
	@echo "⏳ Waiting for Pods to be ready..."
	@vagrant ssh k8s-master -c "kubectl wait --for=condition=ready pod -l app=nginx-test --timeout=300s"
	@echo "✅ Test application deployed. Use 'make validate-test' to check."

# Run cluster validation and deploy test app
test: validate deploy-test


# --- SSH & Logs ---

# SSH into the master node
ssh-master:
	vagrant ssh k8s-master

# SSH into worker nodes
ssh-worker1:
	vagrant ssh k8s-worker1
ssh-worker2:
	vagrant ssh k8s-worker2
ssh-worker3:
	vagrant ssh k8s-worker3

# Check logs from master
logs:
	@echo "📋 Tailing kubelet logs on master node:"
	@vagrant ssh k8s-master -c "sudo journalctl -u kubelet -f -n 50"
