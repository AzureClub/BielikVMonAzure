# GitHub Copilot Instructions - BielikVM

## Project Overview
Automated Azure VM deployment infrastructure for Bielik AI model with Ollama. Supports NVIDIA A100, V100, and T4 GPUs. Infrastructure as Code using Azure Bicep with PowerShell/Bash orchestration scripts.

## Critical Architectural Patterns

### 1. Bicep Variable Injection into Bash Scripts ⚠️ CRITICAL
**Problem**: Direct Bicep variable interpolation (`${variable}`) in inline bash scripts fails because Bicep evaluates before bash, leaving empty strings.

**Solution**: External bash file with placeholder pattern + `loadTextContent()` + `replace()`

```bicep
// In bicep/main.bicep - Custom Script Extension
protectedSettings: {
  script: base64(replace(replace(
    loadTextContent('../scripts/install-ollama-bielik.sh'), 
    '__ADMIN_USER__', adminUsername), 
    '__BIELIK_MODEL__', bielikModel))
}
```

```bash
# In scripts/install-ollama-bielik.sh - Placeholder pattern
ADMIN_USER="__ADMIN_USER__"
BIELIK_MODEL="__BIELIK_MODEL__"
# Bicep replace() substitutes these before base64 encoding
```

**Why other approaches failed**:
- `format()` with `{0}`, `{1}`: Conflicts with JSON braces in heredocs
- String concatenation (`'str' + var + 'str'`): Multi-line compilation errors
- `${adminUsername}` inline: Bicep interpolates leaving bash with empty string
- commandToExecute heredoc: Escape sequence nightmares

### 2. Dual Authentication Mode (Password/SSH)
Uses conditional Bicep logic based on `authenticationType` parameter:

```bicep
param authenticationType string = 'password'
@secure()
param adminPassword string = ''
@secure()
param sshPublicKey string = ''

osProfile: {
  adminPassword: authenticationType == 'password' ? adminPassword : null
  linuxConfiguration: authenticationType == 'sshPublicKey' ? {
    disablePasswordAuthentication: true
    ssh: {
      publicKeys: [{
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: sshPublicKey
      }]
    }
  } : {
    disablePasswordAuthentication: false
  }
}
```

### 3. PowerShell Azure CLI Parameter Passing ⚠️ CRITICAL
**Problem**: String concatenation with escaping causes NULL parameter values.

**Solution**: Array-based parameter passing with each `--parameters` flag separate:

```powershell
$deploymentCommand = @(
    "deployment", "group", "create",
    "--resource-group", $ResourceGroupName,
    "--template-file", $bicepFile
)

# Add each parameter separately
$deploymentCommand += "--parameters"
$deploymentCommand += "@$parametersFile"

$deploymentCommand += "--parameters"
$deploymentCommand += "adminPassword=$passwordPlainText"

$deploymentResult = & az @deploymentCommand 2>&1
```

### 4. Output Parsing from Azure CLI
**Problem**: `az deployment group create` output contains warnings before JSON, breaking `ConvertFrom-Json`.

**Solution**: Query outputs directly from Azure after deployment:

```powershell
$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query properties.outputs `
    --output json 2>$null | ConvertFrom-Json
```

### 5. NSG Conditional Rules
Port 11434 (Ollama API) controlled by parameter:

```bicep
param enablePublicOllamaAccess bool = false

securityRules: [
  {
    name: 'Ollama-API'
    properties: {
      access: enablePublicOllamaAccess ? 'Allow' : 'Deny'
      destinationPortRange: '11434'
    }
  }
]
```

## Project Structure
```
BielikVM/
├── bicep/
│   └── main.bicep                    # Main IaC template (405 lines)
├── scripts/
│   ├── deploy.ps1                    # PowerShell orchestration (380 lines)
│   ├── deploy.sh                     # Bash orchestration
│   └── install-ollama-bielik.sh      # VM setup script with placeholders (123 lines)
├── parameters/
│   ├── dev.parameters.json           # Development environment
│   ├── staging.parameters.json       # Staging environment
│   ├── prod.parameters.json          # Production (NC A100 v4)
│   └── a100.parameters.json          # A100 GPU specific
├── docs/
│   ├── ARCHITECTURE.md               # Technical design
│   ├── COSTS.md                      # Azure cost analysis
│   ├── FAQ.md                        # Common questions
│   └── TROUBLESHOOTING.md            # Debug guide
└── examples/                         # Usage examples
```

## Technical Stack
- **Azure Infrastructure**: VM (Ubuntu 22.04), VNet (10.0.0.0/16), NSG, Static Public IP with DNS
- **GPU Support**: 
  - NVIDIA A100 80GB: `Standard_NC24ads_A100_v4`, `NC48ads_A100_v4`, `NC96ads_A100_v4`
  - NVIDIA V100: `Standard_NC6s_v3`
  - NVIDIA T4: `Standard_NC4as_T4_v3`, `Standard_NC8as_T4_v3`
- **Ollama**: Version 0.13.0, systemd service bound to `0.0.0.0:11434`
- **Bielik Model**: `SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M` (11B params, Q4_K_M quantization)
- **IaC**: Azure Bicep with Custom Script Extension
- **Orchestration**: PowerShell 7+ and Bash

## Language & Documentation
- **Polish language** used throughout:
  - All documentation (README, QUICKSTART, comments)
  - Bicep parameter descriptions (`@description`)
  - Bash script echo statements
  - PowerShell Write-Host messages
- Maintain this pattern when extending the project

## MCAPS Subscription Considerations
- **Azure Policy**: MCAPSGovDenyPolicies at management group level
- **A100 Policy**: Initially blocked `standard_nc*ads_a100_v4` (exemption obtained)
- **Testing**: Always test new VM sizes in target subscription first
- **Location**: `polandcentral` used for production deployments

## Deployment Workflows

### PowerShell (Primary)
```powershell
.\scripts\deploy.ps1 `
    -Environment prod `
    -ResourceGroupName bielik-rg `
    -VmSize Standard_NC24ads_A100_v4 `
    -Location polandcentral `
    -AdminPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -EnablePublicOllamaAccess $true
```

### Bash (Alternative)
```bash
./scripts/deploy.sh \
    --environment prod \
    --resource-group bielik-rg \
    --vm-size Standard_NC24ads_A100_v4
# Script prompts for password interactively
```

## Common Operations

### Reading Bicep Files
- Main template: `bicep/main.bicep` (405 lines)
- Key sections: Parameters (L1-60), NSG (L80-130), VM (L200-250), Custom Script Extension (L250-270)
- Always check Custom Script Extension for bash script injection pattern

### Modifying VM Sizes
1. Add to `@allowed` array in `bicep/main.bicep` (L14-26)
2. Update documentation in `README.md` VM size table
3. Test deployment in target subscription (MCAPS policy check)

### Adding New Parameters
1. Add to `bicep/main.bicep` parameters section with `@description` in Polish
2. Update all parameter files in `parameters/` directory
3. Add to `deploy.ps1` param block with help text
4. Document in `README.md` and `QUICKSTART.md`

### Changing Bash Script Logic
1. Edit `scripts/install-ollama-bielik.sh` directly
2. Use `__PLACEHOLDER__` pattern for any Bicep variables needed
3. Add corresponding `replace()` call in `bicep/main.bicep` Custom Script Extension
4. Test with deployment - script runs as Custom Script Extension

## Debugging Tips

### Deployment Failures
1. Check Azure Activity Log: `Get-AzLog -ResourceGroup $rgName -MaxRecord 20`
2. View VM Extension logs: SSH to VM, check `/var/log/azure/custom-script/handler.log`
3. Test Bicep compilation: `az bicep build --file bicep/main.bicep`
4. Validate parameters: Ensure password meets 12+ char requirement

### Network Issues
1. NSG rules: Verify `enablePublicOllamaAccess` parameter value
2. Check NSG rule: `az network nsg rule show --resource-group $rg --nsg-name bielik-nsg --name Ollama-API`
3. Test connectivity: `curl http://<PUBLIC_IP>:11434/api/version`
4. VM network: SSH to VM, run `ss -tulpn | grep 11434` to verify Ollama binding

### Variable Injection Issues
1. Verify placeholder pattern: `VARIABLE="__PLACEHOLDER__"` in bash script
2. Check Bicep replace() calls: Must be nested inside `base64()`
3. Test on VM: SSH and check `/var/lib/waagent/custom-script/download/0/` for actual executed script
4. Never use `${bicepVariable}` directly in bash - it evaluates to empty string

## Testing Checklist
- [ ] Bicep validation: `az bicep build --file bicep/main.bicep`
- [ ] Parameter file syntax: Valid JSON with all required fields
- [ ] Deployment success: Check exit code and outputs
- [ ] SSH connectivity: Test `ssh azureuser@<PUBLIC_IP>`
- [ ] Ollama service: `systemctl status ollama` on VM
- [ ] Bielik model: `ollama list` shows SpeakLeash/bielik-11b-v2.2-instruct
- [ ] API access: `curl http://<PUBLIC_IP>:11434/api/tags`
- [ ] GPU detection: `nvidia-smi` on GPU-enabled VMs

## Key Resources
- Azure Bicep: https://learn.microsoft.com/azure/azure-resource-manager/bicep/
- Ollama: https://ollama.com/
- Bielik Model: https://huggingface.co/speakleash/bielik-11b-v2.2-instruct
- Custom Script Extension: https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux

## Anti-Patterns to Avoid
❌ Never use `${bicepVariable}` in inline bash scripts
❌ Don't parse `az deployment group create` JSON output directly (contains warnings)
❌ Avoid string concatenation for Azure CLI parameters in PowerShell
❌ Don't use `format()` function for bash scripts with JSON heredocs
❌ Never hardcode sensitive values (passwords, keys) in parameter files
❌ Don't assume A100 GPU availability without subscription policy check

## Success Patterns
✅ External bash script with `__PLACEHOLDER__` + `loadTextContent()` + `replace()`
✅ Array-based PowerShell parameter passing to Azure CLI
✅ Query deployment outputs directly from Azure (avoid parsing warnings)
✅ Conditional Bicep logic for authentication modes
✅ SecureString handling in PowerShell for password parameters
✅ Polish language consistency throughout documentation
✅ Comprehensive parameter validation before deployment
