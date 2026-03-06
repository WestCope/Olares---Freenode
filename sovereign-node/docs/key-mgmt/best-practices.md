# Key Management Best Practices

## Overview

Your SovereignNode has several critical secrets that must be backed up:

1. **Backup encryption key** (Restic) — needed to decrypt backups
2. **Nebula CA key** — needed to add new nodes to your mesh
3. **Solana wallet** — holds your SOV token earnings

Losing any of these means losing access to your data or funds.

---

## The 3-2-1 Backup Rule

Store your keys in at least **3 places**, on **2 different media**, with **1 offsite**:

| Location | Media | Security |
|----------|-------|---------|
| Bitwarden vault | Cloud (encrypted) | Very High |
| Printed paper | Physical | High (use safe) |
| Encrypted USB | Physical | High (store offsite) |

---

## Step-by-Step Key Backup

### Step 1: Generate Your Keys

```bash
bash scripts/key-mgmt/generate-keys.sh
# Output: ~/.sovereign-keys/
# Recovery doc: ~/.sovereign-keys/RECOVERY-INSTRUCTIONS.txt
```

### Step 2: Back Up to Bitwarden

1. Install Bitwarden (https://bitwarden.com) or Vaultwarden (self-hosted)
2. Create a "Secure Note" named "SovereignNode Keys"
3. Paste contents of `RECOVERY-INSTRUCTIONS.txt`
4. Save and verify you can access it from another device

### Step 3: Print Physical Copy

```bash
cat ~/.sovereign-keys/RECOVERY-INSTRUCTIONS.txt | lpr
# Store in a fireproof safe
```

### Step 4: Encrypted USB Backup

```bash
# Create encrypted USB backup
bash scripts/key-mgmt/backup-to-usb.sh /dev/sdX
# Stores to encrypted LUKS partition
```

---

## Solana Wallet Security

Your Solana wallet (`~/.sovereign-keys/solana/keypair.json`) holds your SOV earnings.

### Never Do This
- ❌ Share the `keypair.json` file with anyone
- ❌ Store it on cloud services (Google Drive, Dropbox) unencrypted
- ❌ Send it over email or messaging

### Do This Instead
- ✅ Import into Phantom or Solflare on your trusted phone
- ✅ Write down the seed phrase (if generated with BIP39)
- ✅ Store in Bitwarden as a secure note (encrypted)

### Import into Phantom Wallet

```bash
# Get private key bytes for Phantom import
cat ~/.sovereign-keys/solana/keypair.json | python3 -c "
import json, sys, base58
key = json.load(sys.stdin)
print('Private key (base58):', base58.b58encode(bytes(key[:32])).decode())
print('Import into Phantom using: Settings > Manage Accounts > Import Private Key')
"
```

---

## Recovery Scenarios

### Scenario 1: Node Hardware Failure

1. Get new hardware, install Ubuntu
2. Run bootstrap: `bash poc/bootstrap.sh`
3. Restore data:
   ```bash
   export RESTIC_REPOSITORY="s3:s3.amazonaws.com/my-bucket"
   export RESTIC_PASSWORD="<your-backup-key>"
   restic restore latest --target /opt/sovereign-node/data
   ```
4. Import Nebula certs from backup
5. Start services: `docker compose up -d`

### Scenario 2: Node Stolen

1. **Immediately** rotate DePIN wallet passwords (Mysterium, etc.)
2. If Solana wallet was on node: transfer funds from backup to new wallet
3. Report to DePIN networks that node was stolen
4. Get new hardware, restore from backup (see Scenario 1)

### Scenario 3: Lost All Keys

1. Data backups are unrecoverable without the Restic encryption key
2. SOV tokens: if you have Phantom/wallet backup, funds are safe
3. This is why 3-2-1 backup of keys is critical

---

## Security Checklist

- [ ] Generated keys with `generate-keys.sh`
- [ ] Backed up to Bitwarden or equivalent
- [ ] Printed and stored in safe
- [ ] Encrypted USB stored offsite
- [ ] Tested recovery from backup (at least once!)
- [ ] Solana wallet imported to Phantom on trusted phone
- [ ] .env file excluded from version control (check .gitignore)
