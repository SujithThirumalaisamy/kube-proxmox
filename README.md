# Kubernetes Cluster on Proxmox with Cloud-Init

Automated provisioning of a highly available Kubernetes cluster on Proxmox VE using Terraform for infrastructure and Ansible for cluster configuration.

## Overview

This project automates the deployment of a production-ready Kubernetes cluster with:

- **Terraform**: Provisions VMs on Proxmox using cloud-init for initial configuration
- **Ansible**: Initializes and configures Kubernetes with kubeadm
- **High Availability**: Multi-master setup with stacked etcd
  (API Server is not HA for now)

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │           Proxmox VE Host           │
                    └─────────────────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────┐           ┌───────────────┐           ┌───────────────┐
│   Master 1    │           │   Master 2    │           │   Worker N    │
│  (Primary)    │◄─────────►│ (Secondary)   │           │               │
│               │           │               │           │               │
│ - API Server  │           │ - API Server  │           │ - kubelet     │
│ - etcd        │           │ - etcd        │           │ - kube-proxy  │
│ - Controller  │           │ - Controller  │           │               │
│ - Scheduler   │           │ - Scheduler   │           │               │
└───────────────┘           └───────────────┘           └───────────────┘
```

## Prerequisites

### Infrastructure

- Proxmox VE 7.x or 8.x
- Cloud-init enabled VM template (Ubuntu 22.04 recommended)
- Network configured with DHCP or static IP pool
- API token with VM creation permissions

### Local Machine

- Terraform = 1.13.4
- Ansible = 2.18.6
- SSH key pair for VM access

## Project Structure

```
.
├── scripts/
│   ├── init-config.sh                     # Initialize config files from examples
│   └── setup-kubeconfig.sh                # Kubeconfig merge utility
├── terraform/
│   ├── provider.tf                        # Proxmox provider configuration
│   ├── variables.tf                       # Variable definitions
│   ├── nodes.tf                           # VM resource definitions
│   ├── outputs.tf                         # Output values
│   ├── terraform.tfvars.example           # Infrastructure config template
│   └── credentials.auto.tfvars.example    # Credentials template
└── ansible/
    ├── ansible.cfg                        # Ansible configuration
    ├── site.yml                           # Main playbook
    ├── inventory/
    │   └── hosts.yml.example              # Inventory template
    ├── group_vars/
    │   └── all.yml.example                # Cluster variables template
    └── roles/
        ├── common/                        # Base system setup
        ├── master/                        # Primary master init
        ├── control_plane/                 # Secondary masters
        └── worker/                        # Worker nodes
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/sujiththirumalaisamy/kube-proxmox.git
cd kube-proxmox
```

### 2. Initialize Configuration Files

Use the init script to copy all example configuration files:

```bash
./scripts/init-config.sh
```

This copies the following files:

```bash
# Or copy manually:
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cp terraform/credentials.auto.tfvars.example terraform/credentials.auto.tfvars
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml
```

### 3. Configure Terraform

```bash
# Add your Proxmox credentials
vim terraform/credentials.auto.tfvars

# Configure VM specs, IPs, and infrastructure settings
vim terraform/terraform.tfvars
```

### 4. Provision VMs

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 5. Configure Ansible

```bash
cd ../ansible

# Update inventory with VM IPs from terraform output
vim inventory/hosts.yml

# Configure Kubernetes settings
vim group_vars/all.yml
```

### 6. Initialize Kubernetes Cluster

```bash
ansible-playbook site.yml
```

### 7. Access the Cluster

The playbook automatically fetches the kubeconfig to `ansible/kubeconfig`. Use the setup script to merge it into your local kubectl config:

```bash
./scripts/setup-kubeconfig.sh
```

The script will:

- Check if kubectl is installed
- Ask for custom cluster, user, and context names
- Merge the cluster config without overwriting existing contexts
- Optionally switch to the new context
- Verify cluster connectivity

## Configuration Reference

### Terraform Variables

| Variable              | Description              | Default                 | Required |
| --------------------- | ------------------------ | ----------------------- | -------- |
| `pm_api_url`          | Proxmox API endpoint URL | -                       | Yes      |
| `pm_api_token_id`     | Proxmox API token ID     | -                       | Yes      |
| `pm_api_token_secret` | Proxmox API token secret | -                       | Yes      |
| `vms`                 | Map of VM configurations | `{}`                    | Yes      |
| `template`            | Cloud-init template name | `ubuntu-2204-cloudinit` | No       |
| `storage`             | Storage pool for VMs     | `local-lvm`             | No       |
| `bridge`              | Network bridge           | `vmbr0`                 | No       |
| `gateway`             | Network gateway IP       | -                       | Yes      |
| `nameserver`          | DNS server IP            | -                       | Yes      |
| `cpu_type`            | CPU type for VMs         | `host`                  | No       |
| `bios`                | BIOS type (seabios/ovmf) | `ovmf`                  | No       |
| `username`            | Cloud-init username      | -                       | Yes      |
| `ssh_key`             | SSH public key           | -                       | Yes      |

### VM Configuration Structure

```hcl
vms = {
  "k8s-master-1" = {
    vmid        = 3001
    ip          = "192.168.0.101/24"
    target_node = "pve"
    cores       = 2
    memory      = 4096
    disk_size   = "32G"
    tags        = "kubernetes,master"
    description = "Kubernetes Control Plane Node 1"
  }
  # ... more VMs
}
```

### Ansible Variables (group_vars/all.yml)

| Variable                 | Description                 | Default          |
| ------------------------ | --------------------------- | ---------------- |
| `k8s_version`            | Kubernetes version          | `1.29`           |
| `container_runtime`      | Container runtime           | `containerd`     |
| `pod_network_cidr`       | Pod network CIDR            | `10.244.0.0/16`  |
| `service_cidr`           | Service network CIDR        | `10.96.0.0/12`   |
| `cluster_dns`            | Cluster DNS IP              | `10.96.0.10`     |
| `cluster_name`           | Kubernetes cluster name     | `k8s-production` |
| `cni_plugin`             | CNI plugin (calico/flannel) | `calico`         |
| `api_server_port`        | API server port             | `6443`           |
| `control_plane_endpoint` | Control plane endpoint      | -                |
| `disable_swap`           | Disable swap on nodes       | `true`           |

## Network Planning

When configuring your cluster, ensure these network ranges don't overlap:

| Network         | Purpose             | Example           |
| --------------- | ------------------- | ----------------- |
| Node Network    | VM IP addresses     | `192.168.0.0/24`  |
| Pod Network     | Kubernetes pods     | `10.244.0.0/16`   |
| Service Network | Kubernetes services | `10.96.0.0/12`    |

## Security Considerations

### Credentials Management

**Never commit sensitive files to version control:**

- `credentials.auto.tfvars` - Contains API tokens
- `terraform.tfstate` - Contains sensitive state
- `join_command.sh` - Contains cluster join tokens
- `control_plane_join_command.sh` - Contains control plane join tokens

### Proxmox API Token

Create a dedicated API token with minimal permissions:

```bash
# Proxmox GUI: Datacenter > Permissions > API Tokens
# In Proxmox shell
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role PVEVMAdmin
pveum user token add terraform@pve terraform-token
```

### SSH Key Management

- Use Ed25519 keys for better security
- Consider using SSH agent instead of key file paths
- Rotate keys periodically

### TLS Configuration

For production, enable TLS verification:

```hcl
# In provider.tf
provider "proxmox" {
  pm_tls_insecure = false  # Enable TLS verification
  # Ensure proper certificates are configured on Proxmox
}
```

## Customization

### Adding More Worker Nodes

1. Add VM definition to `terraform.tfvars`:

```hcl
vms = {
  # ... existing VMs
  "k8s-worker-4" = {
    vmid        = 3014
    ip          = "192.168.0.114/24"
    target_node = "pve"
    cores       = 2
    memory      = 4096
    disk_size   = "32G"
    tags        = "kubernetes,worker"
    description = "Kubernetes Worker Node 4"
  }
}
```

2. Update Ansible inventory with new host

3. Run `terraform apply` and `ansible-playbook site.yml`

### Using Different CNI

Set `cni_plugin` in `ansible/group_vars/all.yml`:

```yaml
cni_plugin: flannel # or calico
```

### Custom Calico Configuration

To use a custom Calico manifest with your pod CIDR:

1. Download the manifest:

```bash
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml
```

2. Update the CIDR in the manifest to match your `pod_network_cidr`

3. Place in `terraform/manifests/calico.yaml`

## Troubleshooting

### VM Creation Fails

- Verify Proxmox API token permissions
- Check template exists: `qm list | grep <template-name>`
- Verify storage pool: `pvesm status`

### Kubernetes Init Fails

- Check node connectivity: `ansible all -m ping`
- Verify swap is disabled: `free -h`
- Check container runtime: `systemctl status containerd`

### Nodes Not Joining

- Verify join token hasn't expired (24h default)
- Check network connectivity between nodes
- Verify firewall allows required ports:
  - 6443 (API server)
  - 2379-2380 (etcd)
  - 10250 (kubelet)
  - 10259 (scheduler)
  - 10257 (controller-manager)

### CNI Issues

- Verify pod network CIDR matches CNI configuration
- Check CNI pods are running: `kubectl get pods -n kube-system`
- Review CNI logs: `kubectl logs -n kube-system -l k8s-app=calico-node`

## Outputs

After running Terraform, you can retrieve:

```bash
# All VM IPs
terraform output vm_ips

# Master node IPs only
terraform output master_ips

# Worker node IPs only
terraform output worker_ips
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/my-feature`
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Proxmox VE](https://www.proxmox.com/)
- [Kubernetes](https://kubernetes.io/)
- [Calico](https://www.tigera.io/project-calico/)
- [Terraform Proxmox Provider](https://github.com/Telmate/terraform-provider-proxmox)
