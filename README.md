# Gmail MCP Server

A Nix flake for running the [Gmail MCP Server](https://github.com/GongRzhe/Gmail-MCP-Server) with encrypted credentials managed via agenix.

## Project Structure

```
gmail-mcp/
├── flake.nix                              # Nix flake with all scripts and dependencies
├── flake.lock                             # Locked dependencies
├── secrets.nix                            # Age public keys for encryption
├── secrets/
│   ├── gmail-oauth-credentials.json.age   # Encrypted Google OAuth client credentials
│   └── gmail-oauth-token.json.age         # Encrypted OAuth refresh token
├── .gitignore                             # Excludes unencrypted secrets
└── .envrc                                 # direnv configuration
```

## Prerequisites

- Nix with flakes enabled
- An SSH ed25519 key at `~/.ssh/id_ed25519`
- direnv (optional but recommended)

## Quick Start (Existing Setup)

If the encrypted secrets already exist and your SSH key is in `secrets.nix`:

```bash
git clone https://github.com/colonelpanic8/gmail-mcp.git
cd gmail-mcp
direnv allow  # or: nix develop
gmail-mcp-setup  # Decrypts credentials to ~/.gmail-mcp/
```

Then configure Claude Code:

```bash
claude mcp add --scope user gmail -- nix run github:colonelpanic8/gmail-mcp
```

## Initial Setup (New Installation)

### 1. Clone and enter the development shell

```bash
git clone https://github.com/colonelpanic8/gmail-mcp.git
cd gmail-mcp
direnv allow  # or: nix develop
```

### 2. Set up Google Cloud OAuth

1. Create a Google Cloud project at https://console.cloud.google.com
2. Enable the Gmail API
3. Configure OAuth consent screen (External, add your email as test user)
4. Create OAuth credentials (Desktop app)
5. Download the credentials JSON

### 3. Add your age public key to secrets.nix

```bash
# Get your age public key from your SSH key
ssh-to-age < ~/.ssh/id_ed25519.pub

# Edit secrets.nix and replace/add your public key
```

### 4. Encrypt your credentials

```bash
# Encrypt the OAuth client credentials
age -r "YOUR_AGE_PUBLIC_KEY" -o secrets/gmail-oauth-credentials.json.age credentials.json

# Remove the unencrypted file
rm credentials.json
```

### 5. Authenticate with Gmail

```bash
gmail-mcp-setup  # Decrypts credentials to ~/.gmail-mcp/
npx @gongrzhe/server-gmail-autoauth-mcp auth  # Opens browser for OAuth
gmail-mcp-encrypt-token  # Encrypts the token for portability
git add secrets/gmail-oauth-token.json.age && git commit -m "Add encrypted token"
```

## Commands

| Command | Description |
|---------|-------------|
| `gmail-mcp-setup` | Decrypt credentials and token to `~/.gmail-mcp/` |
| `gmail-mcp-server` | Run the Gmail MCP server |
| `gmail-mcp-encrypt-token` | Encrypt token after OAuth authentication |

## Testing the Setup

```bash
# Verify credentials are decrypted
ls -la ~/.gmail-mcp/
# Should show: gcp-oauth.keys.json and credentials.json

# Test the server starts (Ctrl+C to stop)
gmail-mcp-server

# The server communicates via stdio - it will appear to hang waiting for input
# This is normal. Use Ctrl+C to exit.
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GMAIL_MCP_SECRETS_DIR` | `~/.gmail-mcp` | Directory for decrypted credentials |
| `SSH_KEY` | `~/.ssh/id_ed25519` | SSH key for age decryption |
| `GMAIL_MCP_REPO` | Current directory | Repo path for encrypting token |

## Adding Additional Users

To allow another person/machine to decrypt the secrets:

1. Get their age public key: `ssh-to-age < their_key.pub`
2. Add it to `secrets.nix`
3. Re-encrypt the secrets with all keys:

```bash
agenix -r  # Re-encrypts all secrets with updated keys
```

## Troubleshooting

### "No credentials file found"
- Make sure you're running commands from the repo directory
- Or set `GMAIL_MCP_REPO=/path/to/gmail-mcp`

### "age: error: no identity matched any of the recipients"
- Your SSH key doesn't match any public key in `secrets.nix`
- Add your age public key to `secrets.nix` and run `agenix -r`

### OAuth token expired
```bash
npx @gongrzhe/server-gmail-autoauth-mcp auth  # Re-authenticate
gmail-mcp-encrypt-token  # Re-encrypt the new token
```

## Security Notes

- OAuth credentials and tokens are encrypted with age and safe to commit
- Only users with matching SSH keys in `secrets.nix` can decrypt
- Decrypted credentials stored in `~/.gmail-mcp/` are excluded from git
- The `.age` files use age encryption with your SSH key converted via ssh-to-age

## For AI Agents

This section provides context for AI coding assistants working with this repo.

### Key Files
- `flake.nix` - Contains all shell scripts (`gmail-mcp-setup`, `gmail-mcp-server`, `gmail-mcp-encrypt-token`) as Nix derivations
- `secrets.nix` - List of age public keys that can decrypt secrets
- `secrets/*.age` - Encrypted files (credentials and OAuth token)

### Common Tasks

**User wants to use Gmail MCP:**
1. Ensure `gmail-mcp-setup` has been run (checks for `~/.gmail-mcp/credentials.json`)
2. The MCP server is available via `nix run github:colonelpanic8/gmail-mcp`

**User needs to add a new machine/person:**
1. Get their age public key: `ssh-to-age < ~/.ssh/id_ed25519.pub`
2. Add to `secrets.nix`
3. Run `agenix -r` to re-encrypt

**OAuth token expired:**
1. Run `npx @gongrzhe/server-gmail-autoauth-mcp auth`
2. Run `gmail-mcp-encrypt-token`
3. Commit the updated `.age` file

### What NOT to Do
- Never commit unencrypted `.json` files in `secrets/`
- Never expose the contents of decrypted credentials
- Don't modify encrypted `.age` files directly - use age/agenix commands
