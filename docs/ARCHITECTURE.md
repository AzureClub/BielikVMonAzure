# Architektura - Bielik na Azure VM

## 📐 Diagram architektury

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ HTTPS/SSH/API
                         │
                    ┌────▼────┐
                    │ Public  │
                    │   IP    │  Static IP + DNS Label
                    │(Standard)│
                    └────┬────┘
                         │
┌────────────────────────┼────────────────────────────────────────┐
│  Resource Group        │                                        │
│  (bielik-rg)          │                                        │
│                   ┌────▼────┐                                  │
│                   │   NSG   │  Security Rules:                 │
│                   │ (bielik)│  - SSH (22)                      │
│                   └────┬────┘  - Ollama API (11434)            │
│                        │       - HTTP (8080)                   │
│                   ┌────▼─────────────────────┐                 │
│                   │  Virtual Network         │                 │
│                   │  (10.0.0.0/16)          │                 │
│                   │  ┌────────────────────┐ │                 │
│                   │  │ Subnet             │ │                 │
│                   │  │ (10.0.1.0/24)      │ │                 │
│                   │  │                    │ │                 │
│                   │  │  ┌──────────────┐  │ │                 │
│                   │  │  │     NIC      │  │ │                 │
│                   │  │  └──────┬───────┘  │ │                 │
│                   │  └─────────┼──────────┘ │                 │
│                   └────────────┼────────────┘                 │
│                                │                               │
│                   ┌────────────▼──────────────┐                │
│                   │    Virtual Machine        │                │
│                   │    (bielik-vm)            │                │
│                   │                           │                │
│                   │  Ubuntu 22.04 LTS         │                │
│                   │  ┌─────────────────────┐  │                │
│                   │  │   OS Disk           │  │                │
│                   │  │   128GB Premium SSD │  │                │
│                   │  └─────────────────────┘  │                │
│                   │                           │                │
│                   │  ┌─────────────────────┐  │                │
│                   │  │   Ollama Service    │  │                │
│                   │  │   (Port 11434)      │  │                │
│                   │  │                     │  │                │
│                   │  │  ┌───────────────┐  │  │                │
│                   │  │  │ Bielik Model  │  │  │                │
│                   │  │  │ 11B-v2.2-Q4_KM│  │  │                │
│                   │  │  └───────────────┘  │  │                │
│                   │  └─────────────────────┘  │                │
│                   │                           │                │
│                   │  VM Size:                 │                │
│                   │  - Standard_D8s_v3 (CPU)  │                │
│                   │  - Standard_NC6s_v3 (GPU) │                │
│                   └───────────────────────────┘                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT ACCESS                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SSH Access:                                                    │
│  └─> ssh azureuser@<PUBLIC_IP>                                 │
│                                                                 │
│  Ollama CLI:                                                    │
│  └─> ollama run bielik-11b-v2.2-instruct:Q4_K_M                │
│                                                                 │
│  REST API:                                                      │
│  └─> curl http://<PUBLIC_IP>:11434/api/chat                    │
│                                                                 │
│  Python/Node.js:                                                │
│  └─> requests.post("http://<PUBLIC_IP>:11434/api/chat")        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Komponenty

### 1. Network Layer

#### Virtual Network (VNet)
- **Address Space**: 10.0.0.0/16
- **Subnet**: 10.0.1.0/24 (254 dostępne adresy)
- **Purpose**: Izolacja sieciowa i bezpieczeństwo

#### Network Security Group (NSG)
- **Attached to**: Subnet i NIC
- **Rules**:
  - Allow SSH (22) - Priority 1000
  - Allow/Deny Ollama API (11434) - Priority 1100 (configurable)
  - Allow HTTP (8080) - Priority 1200

#### Public IP
- **Type**: Static (Standard SKU)
- **DNS Label**: Auto-generated (bielik-vm-{unique-id})
- **Purpose**: Dostęp z internetu

#### Network Interface (NIC)
- **Type**: Standard
- **IP Config**: Dynamic private IP, Static public IP
- **Connected to**: VM i Subnet

### 2. Compute Layer

#### Virtual Machine
- **OS**: Ubuntu 22.04 LTS (Jammy Jellyfish)
- **Image**: Canonical, 0001-com-ubuntu-server-jammy
- **Authentication**: SSH Key tylko (password disabled)
- **Sizes Available**:
  
  **CPU-Only:**
  - Standard_D4s_v3: 4 vCPU, 16GB RAM
  - Standard_D8s_v3: 8 vCPU, 32GB RAM (default)
  - Standard_D16s_v3: 16 vCPU, 64GB RAM
  
  **GPU:**
  - Standard_NC4as_T4_v3: 4 vCPU, 28GB RAM, Tesla T4 16GB
  - Standard_NC6s_v3: 6 vCPU, 112GB RAM, Tesla V100 16GB
  - Standard_NC8as_T4_v3: 8 vCPU, 56GB RAM, Tesla T4 16GB

### 3. Storage Layer

#### OS Disk
- **Type**: Premium SSD (P10)
- **Size**: 128 GB
- **Performance**: 500 IOPS, 100 MB/s
- **Purpose**: System operacyjny i aplikacje

#### Model Storage
- **Location**: /home/azureuser/.ollama/models/
- **Size**: ~6-8 GB (dla Q4_K_M)
- **Type**: Część OS disk

### 4. Application Layer

#### Ollama Service
- **Type**: systemd service
- **Port**: 11434
- **Bind**: 0.0.0.0 (all interfaces)
- **Auto-start**: Enabled
- **Configuration**: /etc/systemd/system/ollama.service.d/

#### Bielik Model
- **Name**: SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M
- **Size**: ~6.5 GB
- **Quantization**: Q4_K_M (4-bit)
- **Parameters**: 11 Billion
- **Context Window**: 8K tokens

### 5. Management Layer

#### VM Extension
- **Type**: CustomScript Extension
- **Purpose**: Automatyczna instalacja
- **Script**: Inline bash
- **Logs**: /var/log/azure/custom-script/

#### Auto-shutdown (Optional)
- **Type**: Azure Automation
- **Configuration**: Manual setup post-deployment
- **Purpose**: Oszczędność kosztów

## 🔄 Przepływ deploymentu

```
1. Pre-deployment
   ├─> Walidacja Azure CLI
   ├─> Login check
   ├─> SSH key generation/verification
   └─> Parameter validation

2. Resource Group
   └─> Create or use existing

3. Network Infrastructure
   ├─> Create NSG with rules
   ├─> Create VNet with subnet
   ├─> Create Public IP
   └─> Create NIC (attached to subnet & NSG)

4. Virtual Machine
   ├─> Create VM with specified size
   ├─> Attach OS Disk (Premium SSD)
   ├─> Configure SSH auth
   └─> Attach NIC

5. VM Extension (runs on VM)
   ├─> Update system packages
   ├─> Install dependencies (curl, git, htop)
   ├─> Install Ollama
   ├─> Configure Ollama service
   ├─> Download Bielik model (~10-15 min)
   ├─> Create helper scripts
   └─> Verify installation

6. Post-deployment
   ├─> Retrieve outputs (IP, FQDN, etc.)
   ├─> Display connection info
   └─> Save to deployment-output.json
```

## 🔐 Security Architecture

### Network Security

```
Internet
   │
   ├─> NSG Rules (Firewall)
   │   ├─> Allow: SSH (22) from ANY
   │   ├─> Allow/Deny: Ollama (11434) - Configurable
   │   └─> Allow: HTTP (8080) from ANY
   │
   └─> VM
       └─> iptables (OS-level, if configured)
```

### Authentication
- **SSH**: Public key only
- **No passwords**: Disabled at OS level
- **Ollama API**: No authentication (use NSG for security)

### Best Practices Applied
1. **No password authentication**: SSH key required
2. **NSG**: Granular port control
3. **Public IP**: Isolated from other resources
4. **Separate subnet**: Network segmentation
5. **Standard Public IP**: Required for Standard NSG

## 📊 Data Flow

### Request Flow (API Call)

```
Client
  │
  │ HTTP POST
  │ http://<PUBLIC_IP>:11434/api/chat
  │
  ▼
Public IP (Static)
  │
  │ NAT
  │
  ▼
NSG (Network Security Group)
  │
  │ Rule Check: Port 11434 allowed?
  │
  ▼
NIC (Private IP: 10.0.1.x)
  │
  │
  ▼
VM - iptables (if configured)
  │
  │
  ▼
Ollama Service (0.0.0.0:11434)
  │
  │ Load model
  │
  ▼
Bielik Model (in memory)
  │
  │ Generate response
  │
  ▼
Return JSON response
  │
  │ Same path back
  │
  ▼
Client
```

### SSH Access Flow

```
Client
  │
  │ SSH (Port 22)
  │ ssh azureuser@<PUBLIC_IP>
  │
  ▼
Public IP
  │
  ▼
NSG
  │
  │ Allow SSH (Port 22)
  │
  ▼
NIC
  │
  ▼
VM - sshd
  │
  │ Validate SSH key
  │
  ▼
Shell access
```

## 🔄 High Availability Options

### Single VM (Current)
```
┌────────────┐
│   Client   │
└─────┬──────┘
      │
      ▼
┌────────────┐
│   VM-1     │  ← Single point of failure
│  + Bielik  │
└────────────┘
```

### Load Balanced (Future Enhancement)
```
┌────────────┐
│   Client   │
└─────┬──────┘
      │
      ▼
┌─────────────────┐
│ Load Balancer   │
└────┬────────┬───┘
     │        │
     ▼        ▼
┌─────────┐ ┌─────────┐
│  VM-1   │ │  VM-2   │  ← Redundancy
│ +Bielik │ │ +Bielik │
└─────────┘ └─────────┘
```

## 📈 Scaling Options

### Vertical Scaling (Scale Up)
```powershell
# Increase VM size
az vm deallocate -g bielik-rg -n bielik-vm
az vm resize -g bielik-rg -n bielik-vm --size Standard_D16s_v3
az vm start -g bielik-rg -n bielik-vm
```

### Horizontal Scaling (Scale Out)
```
Deploy multiple VMs + Load Balancer
(Requires additional Bicep modifications)
```

## 🌍 Multi-Region Deployment

```
┌──────────────┐          ┌──────────────┐
│ West Europe  │          │ North Europe │
│              │          │              │
│  ┌────────┐  │          │  ┌────────┐  │
│  │ VM-WE  │  │          │  │ VM-NE  │  │
│  │+Bielik │  │          │  │+Bielik │  │
│  └────────┘  │          │  └────────┘  │
└──────┬───────┘          └───────┬──────┘
       │                          │
       └──────────┬───────────────┘
                  │
            ┌─────▼─────┐
            │  Traffic  │
            │  Manager  │
            └───────────┘
```

## 💾 Backup Architecture

```
VM + Ollama + Model
        │
        │ Azure Backup (optional)
        │
        ▼
┌─────────────────────┐
│ Recovery Services   │
│      Vault          │
│                     │
│  Daily Backups      │
│  Retention: 30 days │
└─────────────────────┘
```

## 🎯 Summary

**Strengths:**
- ✅ Simple, single-VM architecture
- ✅ Easy to deploy and manage
- ✅ Cost-effective for development
- ✅ Full control over environment
- ✅ Quick setup (~15-20 minutes)

**Limitations:**
- ⚠️ Single point of failure
- ⚠️ No auto-scaling
- ⚠️ Manual backup required
- ⚠️ Limited to single region

**Recommended For:**
- Development and testing
- POCs and MVPs
- Small to medium workloads
- Learning and experimentation
- Cost-sensitive projects
