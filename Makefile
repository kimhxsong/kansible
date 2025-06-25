# Makefile for managing the Kubernetes cluster
.PHONY: all up network cluster re clean fclean reset down

# Default settings
VAGRANT_MACHINES = k8s-master k8s-worker1 k8s-worker2 k8s-worker3
ANSIBLE_INVENTORY = ansible/inventory.ini

# --- Plugin Check ---
check-plugin:
	@if ! vagrant plugin list | grep -q vagrant-disksize; then \
		echo "[INFO] vagrant-disksize plugin not found. Installing automatically..."; \
		vagrant plugin install vagrant-disksize; \
	else \
		echo "[INFO] vagrant-disksize plugin already installed."; \
	fi

# --- Main Targets ---

all: cluster

up: check-plugin
	@echo "[INFO] Creating and starting all VMs..."
	vagrant up
	@echo "[SUCCESS] All VMs are up and running."

network: up
	@echo "[INFO] Configuring static IP and /etc/hosts..."
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/configure-network.yml
	@echo "[SUCCESS] Network configuration complete."

cluster: network
	@echo "[INFO] Configuring Kubernetes cluster..."
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/configure-cluster.yml
	@echo "[SUCCESS] Cluster configuration complete."


reset:
	@echo "[INFO] Resetting the Kubernetes cluster only..."
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/reset-cluster.yml
	@echo "[SUCCESS] Cluster reset complete."

validate:
	@echo "[INFO] Validating cluster status..."
	@vagrant ssh k8s-master -c "kubectl get nodes -o wide"
	@echo ""
	@vagrant ssh k8s-master -c "kubectl get pods -A"

down:
	@echo "[INFO] Stopping all VMs..."
	vagrant halt
	@echo "[SUCCESS] All VMs have been stopped."

clean: down
	@echo "[INFO] Destroying all VMs..."
	vagrant destroy -f
	@echo "[SUCCESS] All VMs destroyed."

re: down cluster
