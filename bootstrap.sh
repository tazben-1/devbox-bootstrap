#!/bin/bash

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 DevBox Bootstrap - User & Git Setup${NC}"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}❌ Error: Do not run as root. Run as your regular user.${NC}"
  exit 1
fi

# Verify we can use sudo without password
if ! sudo -n true 2>/dev/null; then
  echo -e "${YELLOW}ℹ️  You may be prompted for your password (for sudo)${NC}"
fi

# Interactive prompts (not passed via args to avoid shell history exposure)
echo -e "${YELLOW}📋 Configuration:${NC}"

read -p "  Username? (default: devbox): " DEVBOX_USERNAME
DEVBOX_USERNAME=${DEVBOX_USERNAME:-devbox}

echo "  Git Auth Method:"
echo "    [1] SSH key (recommended)"
echo "    [2] GitHub token"
read -p "  Choose [1-2] (default: 1): " AUTH_CHOICE
AUTH_CHOICE=${AUTH_CHOICE:-1}

if [ "$AUTH_CHOICE" == "2" ]; then
  GITHUB_AUTH_METHOD="token"
else
  GITHUB_AUTH_METHOD="ssh"
fi

echo
echo "  Selected: $DEVBOX_USERNAME / $GITHUB_AUTH_METHOD"
echo

# Step 1: Create user
echo -e "${YELLOW}👤 Creating user '$DEVBOX_USERNAME'...${NC}"

if id "$DEVBOX_USERNAME" &>/dev/null; then
  echo -e "${GREEN}✓ User already exists${NC}"
else
  sudo useradd -m -s /bin/bash "$DEVBOX_USERNAME" || {
    echo -e "${RED}❌ Failed to create user${NC}"
    exit 1
  }
  echo -e "${GREEN}✓ User created${NC}"
fi

# Step 2: Setup Git credentials
echo
echo -e "${YELLOW}🔑 Setting up Git credentials...${NC}"

if [ "$GITHUB_AUTH_METHOD" == "ssh" ]; then
  # SSH key method - generate new key or use existing
  SSH_DIR="/home/$DEVBOX_USERNAME/.ssh"

  echo -e "${YELLOW}🔑 SSH Key Setup${NC}"

  # Create .ssh directory
  sudo mkdir -p "$SSH_DIR"
  sudo chmod 700 "$SSH_DIR"

  SSH_KEY_PATH="$SSH_DIR/id_rsa_github"

  # Check if key already exists
  if sudo test -f "$SSH_KEY_PATH"; then
    echo -e "${GREEN}✓ SSH key already exists${NC}"
  else
    echo -e "${YELLOW}Generating new ED25519 SSH key...${NC}"

    # Generate key as root, then chown
    sudo ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "devbox@github" > /dev/null 2>&1
    sudo chmod 600 "$SSH_KEY_PATH"
    sudo chmod 644 "$SSH_KEY_PATH.pub"
    sudo chown "$DEVBOX_USERNAME:$DEVBOX_USERNAME" "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"

    echo -e "${GREEN}✓ SSH key generated${NC}"
  fi

  # Display public key for GitHub and copy to clipboard
  PUBKEY=$(sudo cat "$SSH_KEY_PATH.pub")

  echo
  echo -e "${YELLOW}📋 SSH Public Key (copied to clipboard):${NC}"
  echo
  echo "$PUBKEY" | sed 's/^/  /'
  echo

  # Try to copy to clipboard
  if command -v clip.exe &> /dev/null; then
    # WSL: use Windows clipboard
    echo "$PUBKEY" | clip.exe
    echo -e "${GREEN}✓ Key copied to Windows clipboard${NC}"
  elif command -v xclip &> /dev/null; then
    # Linux: use xclip
    echo "$PUBKEY" | xclip -selection clipboard
    echo -e "${GREEN}✓ Key copied to clipboard${NC}"
  elif command -v wl-copy &> /dev/null; then
    # Wayland: use wl-copy
    echo "$PUBKEY" | wl-copy
    echo -e "${GREEN}✓ Key copied to clipboard${NC}"
  else
    echo -e "${YELLOW}ℹ️  Clipboard tools not available - key displayed above${NC}"
  fi

  echo
  echo -e "${YELLOW}📝 Next:${NC}"
  echo "  1. Go to: https://github.com/settings/keys"
  echo "  2. Click 'New SSH key'"
  echo "  3. Paste the key (it's in your clipboard)"
  echo "  4. Click 'Add SSH key'"
  echo
  read -p "  Press Enter once you've added the key to GitHub... "

  # Create SSH config for GitHub
  SSH_CONFIG="$SSH_DIR/config"
  if ! sudo test -f "$SSH_CONFIG"; then
    sudo tee "$SSH_CONFIG" > /dev/null <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_rsa_github
  StrictHostKeyChecking accept-new
EOF
    sudo chmod 600 "$SSH_CONFIG"
    sudo chown "$DEVBOX_USERNAME:$DEVBOX_USERNAME" "$SSH_CONFIG"
  fi

elif [ "$GITHUB_AUTH_METHOD" == "token" ]; then
  # GitHub token method - prompt for token interactively
  echo -e "${YELLOW}🔑 GitHub Token Setup${NC}"
  echo "  Get your token at: https://github.com/settings/tokens"
  echo "  Scopes needed: repo, read:user"
  echo

  read -sp "  GitHub token (won't be echoed): " GITHUB_TOKEN
  echo

  if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}❌ Token is required${NC}"
    exit 1
  fi

  GIT_CONFIG_DIR="/home/$DEVBOX_USERNAME/.config/git"
  sudo mkdir -p "$GIT_CONFIG_DIR"
  sudo chown "$DEVBOX_USERNAME:$DEVBOX_USERNAME" "$GIT_CONFIG_DIR"
  sudo chmod 700 "$GIT_CONFIG_DIR"

  # Store token in git credentials
  sudo tee "/home/$DEVBOX_USERNAME/.git-credentials" > /dev/null <<EOF
https://oauth2:${GITHUB_TOKEN}@github.com
EOF
  sudo chmod 600 "/home/$DEVBOX_USERNAME/.git-credentials"
  sudo chown "$DEVBOX_USERNAME:$DEVBOX_USERNAME" "/home/$DEVBOX_USERNAME/.git-credentials"

  # Configure git to use stored credentials
  sudo -u "$DEVBOX_USERNAME" git config --global credential.helper store
  echo -e "${GREEN}✓ GitHub token stored${NC}"
fi


# Step 3: Test git access
echo
echo -e "${YELLOW}🧪 Testing Git access...${NC}"

if [ "$GITHUB_AUTH_METHOD" == "ssh" ]; then
  # Add GitHub to known hosts
  sudo -u "$DEVBOX_USERNAME" ssh-keyscan -t ed25519,rsa github.com >> "/home/$DEVBOX_USERNAME/.ssh/known_hosts" 2>/dev/null || true

  # Test SSH connection with retry (GitHub key may take a few seconds to propagate)
  SSH_TEST_PASSED=0
  for attempt in 1 2 3; do
    echo -n "  Attempt $attempt/3... "
    SSH_OUTPUT=$(sudo -u "$DEVBOX_USERNAME" timeout 10 ssh -T git@github.com 2>&1 || true)

    if echo "$SSH_OUTPUT" | grep -qE "Hi [a-zA-Z0-9_-]+|successfully authenticated"; then
      echo -e "${GREEN}✓${NC}"
      SSH_TEST_PASSED=1
      echo -e "${GREEN}✓ GitHub SSH access verified${NC}"
      echo "  User: $(echo "$SSH_OUTPUT" | grep -oE 'Hi [a-zA-Z0-9_-]+' | cut -d' ' -f2)"
      break
    else
      echo -e "${YELLOW}retry${NC}"
      if [ $attempt -lt 3 ]; then
        sleep 2
      fi
    fi
  done

  if [ $SSH_TEST_PASSED -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Could not verify SSH access${NC}"
    echo "  This can happen if:"
    echo "  - Key wasn't added to GitHub yet"
    echo "  - GitHub is still propagating the key (~30 seconds)"
    echo "  - GitHub account access issues"
    echo
    echo "  Verify manually after bootstrap:"
    echo "    ssh -T git@github.com"
    echo
    echo "  Debug the connection:"
    echo "    ssh -vvv git@github.com"
  fi
else
  # Token test - attempt a git ls-remote to verify it works
  echo "  Testing GitHub token..."
  if sudo -u "$DEVBOX_USERNAME" timeout 10 git ls-remote https://github.com/tazben-1/iplak-devbox.git > /dev/null 2>&1; then
    echo -e "${GREEN}✓ GitHub token access verified${NC}"
  else
    echo -e "${YELLOW}⚠️  Could not verify token access${NC}"
    echo "  Verify token scopes: https://github.com/settings/tokens"
    echo "  Required: 'repo' and 'read:user'"
    echo "  Token will be tested during 'git clone' in next step"
  fi
fi

# Step 4: Setup shell profile
echo
echo -e "${YELLOW}⚙️  Setting up shell...${NC}"

BASHRC="/home/$DEVBOX_USERNAME/.bashrc"
if ! sudo -u "$DEVBOX_USERNAME" grep -q "DEVBOX_USER=" "$BASHRC" 2>/dev/null; then
  sudo tee -a "$BASHRC" > /dev/null <<'EOF'

# DevBox environment
export DEVBOX_USER=1
EOF
  echo -e "${GREEN}✓ Shell environment configured${NC}"
fi

# Step 5: Summary
echo
echo -e "${GREEN}✅ Bootstrap complete!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Switch to the new user:"
echo "     su - $DEVBOX_USERNAME"
echo
echo "  2. Clone the DevBox project:"
echo "     git clone https://github.com/tazben-1/iplak-devbox.git"
echo "     cd iplak-devbox"
echo
echo "  3. Run provisioning:"
echo "     ./install.sh"
echo
