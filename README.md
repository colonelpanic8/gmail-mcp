# Gmail MCP Server

A Nix flake for running the [Gmail MCP Server](https://github.com/GongRzhe/Gmail-MCP-Server) with encrypted credentials managed via agenix.

## Prerequisites

- Nix with flakes enabled
- An SSH ed25519 key at `~/.ssh/id_ed25519`
- direnv (optional but recommended)

## Initial Setup (First Machine)

### 1. Clone and enter the development shell

```bash
git clone https://github.com/imalison/gmail-mcp.git
cd gmail-mcp
direnv allow  # or: nix develop
```

### 2. Set up Google Cloud OAuth

1. Create a Google Cloud project at https://console.cloud.google.com
2. Enable the Gmail API
3. Configure OAuth consent screen (External, add your email as test user)
4. Create OAuth credentials (Desktop app)
5. Download the credentials JSON

### 3. Encrypt your credentials

```bash
# Get your age public key from your SSH key
ssh-to-age < ~/.ssh/id_ed25519.pub

# Update secrets.nix with your age public key
# Then encrypt your credentials:
age -r "YOUR_AGE_PUBLIC_KEY" -o secrets/gmail-oauth-credentials.json.age credentials.json

# Remove the unencrypted file
rm credentials.json
```

### 4. Authenticate with Gmail

```bash
gmail-mcp-setup  # Decrypts credentials to ~/.gmail-mcp/
npx @gongrzhe/server-gmail-autoauth-mcp auth  # Opens browser for OAuth
gmail-mcp-encrypt-token  # Encrypts the token for portability
git add secrets/gmail-oauth-token.json.age && git commit -m "Add encrypted token"
```

## Setup on Additional Machines

```bash
git clone https://github.com/imalison/gmail-mcp.git
cd gmail-mcp
direnv allow  # or: nix develop
gmail-mcp-setup  # Decrypts credentials and token
```

## Usage

### Run the Gmail MCP server

```bash
gmail-mcp-server
```

### Configure Claude Code

Add to your Claude Code MCP configuration:

```json
{
  "mcpServers": {
    "gmail": {
      "command": "nix",
      "args": ["run", "github:imalison/gmail-mcp"]
    }
  }
}
```

Or if you have the repo cloned locally:

```json
{
  "mcpServers": {
    "gmail": {
      "command": "nix",
      "args": ["run", "/path/to/gmail-mcp"]
    }
  }
}
```

## Commands

| Command | Description |
|---------|-------------|
| `gmail-mcp-setup` | Decrypt credentials and set up `~/.gmail-mcp/` |
| `gmail-mcp-server` | Run the Gmail MCP server |
| `gmail-mcp-encrypt-token` | Encrypt token after OAuth authentication |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GMAIL_MCP_SECRETS_DIR` | `~/.gmail-mcp` | Directory for decrypted credentials |
| `SSH_KEY` | `~/.ssh/id_ed25519` | SSH key for age decryption |
| `GMAIL_MCP_REPO` | Current directory | Repo path for encrypting token |

## Adding Additional Users

To allow another user to decrypt the secrets:

1. Get their age public key: `ssh-to-age < their_key.pub`
2. Add it to `secrets.nix`
3. Re-encrypt the secrets with all keys:

```bash
agenix -r  # Re-encrypts all secrets with updated keys
```

## Security Notes

- OAuth credentials and tokens are encrypted with age and can be safely committed to git
- Only users with matching SSH keys in `secrets.nix` can decrypt the secrets
- Decrypted credentials are stored in `~/.gmail-mcp/` and excluded from git
