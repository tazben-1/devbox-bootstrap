# 🚀 DevBox Bootstrap

Minimal WSL2 initialization: create a dedicated user and configure Git credentials. This is **step 1 of 2** — the actual project setup happens in step 2.

## Quick Start (Two Commands)

### Step 1: Bootstrap User & Git

```bash
curl -sSL https://raw.githubusercontent.com/tazben-1/devbox-bootstrap/v1.0.0/bootstrap.sh | bash
```

The script will prompt you for:
- **Username** (default: `devbox`)
- **Auth method:** SSH key or GitHub token
- **SSH key or token** (you'll paste the public key into GitHub, or provide a token)

**What it does:**
- Creates a dedicated user
- Generates a new SSH key locally (or prompts for token)
- Shows you the public key to add to GitHub
- Verifies Git access
- Sets up shell environment

### Step 2: Clone & Provision

```bash
su - devbox
git clone https://github.com/tazben-1/iplak-devbox.git
cd iplak-devbox
./install.sh
```

**What it does:**
- Installs Ansible and dev tools
- Sets up Docker services (PostgreSQL, etc.)
- Clones IPLAK monorepo
- Full provisioning with zero re-prompts for user/git

---

## Manual Usage (Without Curl)

```bash
# Clone this repo
git clone https://github.com/tazben-1/devbox-bootstrap.git
cd devbox-bootstrap

# Run bootstrap (interactive prompts)
chmod +x bootstrap.sh
./bootstrap.sh
```

---

## Prerequisites

✅ **WSL2 with Ubuntu** (default from `wsl --install`)
✅ **Sudo access** (you'll be prompted if needed)
✅ **GitHub account** (for SSH key upload or token creation)

## How It Works

### Option A: SSH Key (Recommended)

1. Script **generates a new ED25519 key locally** in `~/.ssh/id_rsa_github`
2. Script **automatically copies the public key to your clipboard** (on WSL/Linux)
3. You **paste it into GitHub** → Settings → SSH and GPG keys (just Ctrl+V)
4. Script **verifies the connection** with automatic retries (waits for GitHub to propagate)

**Advantages:**
- No tokens to manage
- Key never exposed in shell history
- Automatic clipboard copy (no manual selection needed)
- Can be revoked per-device on GitHub
- Better security practice

### Option B: GitHub Token (PAT)

1. You **create a token** at GitHub → Settings → Developer settings → Personal access tokens
2. Script **prompts for the token** (input is hidden)
3. Script **stores it safely** in `~/.git-credentials` (mode 600)
4. Script **verifies access** before completing

**Scopes needed:** `repo`, `read:user`

**Advantages:**
- No local SSH key to manage
- Can be rotated easily on GitHub
- Useful if you have SSH disabled elsewhere

---

## What Gets Created

Inside `/home/devbox/`:
```
.ssh/
├── id_rsa_github          # Private key (SSH method - generated locally)
├── id_rsa_github.pub      # Public key (SSH method - for GitHub)
├── config                 # SSH client config
└── known_hosts            # GitHub host key

.bashrc                    # Shell environment additions
.git-credentials           # GitHub token (token method only)
.config/git/               # Git config directory
```

**Key points:**
- SSH key is **generated locally** — never sent anywhere
- SSH public key is **automatically copied to clipboard** (WSL/Linux) — just paste into GitHub
- Token is **read interactively** — not visible in shell history
- All files are owned by the new user with restricted permissions (600)

---

## Troubleshooting

**"User already exists"?**
- Script will reuse the existing user
- Check: `su - <username>` works

**"Permission denied (publickey)" after bootstrap?**
- Did you paste the SSH key into GitHub?
  - GitHub → Settings → SSH and GPG keys
  - Look for the key starting with `ssh-ed25519`
- GitHub may need a moment to propagate the key (wait 30 seconds)
- Test manually: `ssh -T git@github.com`

**"Cannot sudo without password"?**
- Script will prompt for your password when needed
- Or set up passwordless sudo: `sudo visudo` and add `$USER ALL=(ALL) NOPASSWD:ALL`

**"Token verification failed"?**
- Verify token scopes: https://github.com/settings/tokens
- Required: `repo` and `read:user`
- Make sure token hasn't expired
- Try again in step 2: `git clone https://github.com/...`

**"SSH keyscan failed"?**
- This is non-critical — the script continues
- GitHub's host key will be added on first connection

**"Script hangs at 'Press Enter'"?**
- You need to add the SSH public key to GitHub
- The key is already in your clipboard — just paste (Ctrl+V)
- Go to https://github.com/settings/keys
- Click "New SSH key"
- Paste the key and click "Add SSH key"
- Then press Enter in the terminal

**"SSH key copied to clipboard" but I don't see a message?**
- Clipboard support depends on your environment:
  - **WSL2:** Uses Windows clipboard via `clip.exe` ✓
  - **Linux:** Uses `xclip` if available ✓
  - **Wayland:** Uses `wl-copy` if available ✓
  - If none available: key is displayed, copy manually
- The key is always displayed in the terminal as fallback

**"Warning: Could not verify SSH access (GitHub may need a moment)"?**
- GitHub can take 10-30 seconds to propagate new keys
- The script tries 3 times automatically
- Verify manually after a minute: `ssh -T git@github.com`
- Should respond with "Hi your-username!"

---

## Security Notes

🔒 **SSH Keys:**
- **Generated locally** in `~/.ssh/id_rsa_github` (never sent anywhere)
- Private key stored with mode `600` (readable only by owner)
- Public key copy-pasted manually into GitHub (you control this step)
- Key never appears in shell history

🔒 **Tokens:**
- **Prompted interactively** with hidden input (like password)
- Token never appears in shell history or command line
- Stored in `~/.git-credentials` with mode `600`
- Only accessible by the owning user

🔒 **Script Safety:**
- Script runs locally (no cloud execution)
- Inspect before running: `curl -sL https://raw.githubusercontent.com/.../bootstrap.sh | less`
- Always use specific version tags (v1.0.0), never `main` or `latest`
- Source code is public and auditable

🔒 **Best Practices:**
- Never share tokens via email, Slack, or git history
- SSH keys are safer than tokens for long-term use
- Rotate tokens every 90 days
- Keep WSL updated: `sudo apt update && sudo apt upgrade`

---

## What's Next

After bootstrap completes, the user `devbox` has everything needed to clone and provision the main project. See step 2 in Quick Start above.

---

## License

MIT
