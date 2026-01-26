{
  description = "Gmail MCP Server with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, agenix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Gmail MCP server setup script
        gmail-mcp-setup = pkgs.writeShellScriptBin "gmail-mcp-setup" ''
          set -e

          SECRETS_DIR="''${GMAIL_MCP_SECRETS_DIR:-$HOME/.gmail-mcp}"
          SSH_KEY="''${SSH_KEY:-$HOME/.ssh/id_ed25519}"
          REPO_DIR="''${GMAIL_MCP_REPO:-$(pwd)}"

          mkdir -p "$SECRETS_DIR"

          # Decrypt OAuth credentials if encrypted file exists
          if [ -f "$REPO_DIR/secrets/gmail-oauth-credentials.json.age" ]; then
            echo "Decrypting OAuth credentials..."
            AGE_SECRET=$(${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$SSH_KEY" 2>/dev/null)
            echo "$AGE_SECRET" | ${pkgs.age}/bin/age -d -i - \
              "$REPO_DIR/secrets/gmail-oauth-credentials.json.age" \
              > "$SECRETS_DIR/gcp-oauth.keys.json"
            echo "Credentials decrypted to $SECRETS_DIR/gcp-oauth.keys.json"
          else
            echo "No credentials file found at $REPO_DIR/secrets/gmail-oauth-credentials.json.age"
            echo "Make sure you're running this from the gmail-mcp repo directory"
            echo "Or set GMAIL_MCP_REPO to the repo path"
            exit 1
          fi

          # Decrypt OAuth token if it exists
          if [ -f "$REPO_DIR/secrets/gmail-oauth-token.json.age" ]; then
            echo "Decrypting OAuth token..."
            AGE_SECRET=$(${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$SSH_KEY" 2>/dev/null)
            echo "$AGE_SECRET" | ${pkgs.age}/bin/age -d -i - \
              "$REPO_DIR/secrets/gmail-oauth-token.json.age" \
              > "$SECRETS_DIR/credentials.json"
            echo "Token decrypted to $SECRETS_DIR/credentials.json"
          else
            echo "No token file found - you'll need to authenticate"
          fi

          echo ""
          echo "Setup complete! Credentials are in $SECRETS_DIR"
        '';

        # Script to encrypt token after authentication
        gmail-mcp-encrypt-token = pkgs.writeShellScriptBin "gmail-mcp-encrypt-token" ''
          set -e

          SECRETS_DIR="''${GMAIL_MCP_SECRETS_DIR:-$HOME/.gmail-mcp}"
          SSH_KEY="''${SSH_KEY:-$HOME/.ssh/id_ed25519}"
          REPO_DIR="''${GMAIL_MCP_REPO:-$(pwd)}"

          if [ ! -f "$SECRETS_DIR/credentials.json" ]; then
            echo "No credentials.json found in $SECRETS_DIR"
            echo "Run 'npx @gongrzhe/server-gmail-autoauth-mcp auth' first"
            exit 1
          fi

          AGE_PUBLIC=$(${pkgs.ssh-to-age}/bin/ssh-to-age < "$SSH_KEY.pub" 2>/dev/null)

          echo "Encrypting credentials.json (OAuth token)..."
          ${pkgs.age}/bin/age -r "$AGE_PUBLIC" \
            -o "$REPO_DIR/secrets/gmail-oauth-token.json.age" \
            "$SECRETS_DIR/credentials.json"

          echo "Token encrypted to $REPO_DIR/secrets/gmail-oauth-token.json.age"
          echo "You can now commit this file to git"
        '';

        # Wrapper script to run the Gmail MCP server
        gmail-mcp-server = pkgs.writeShellScriptBin "gmail-mcp-server" ''
          # The server looks for credentials in ~/.gmail-mcp/ by default
          exec ${pkgs.nodejs_22}/bin/npx @gongrzhe/server-gmail-autoauth-mcp "$@"
        '';

      in
      {
        packages = {
          gmail-mcp-setup = gmail-mcp-setup;
          gmail-mcp-encrypt-token = gmail-mcp-encrypt-token;
          gmail-mcp-server = gmail-mcp-server;
          default = gmail-mcp-server;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Google Cloud CLI for OAuth setup
            google-cloud-sdk

            # Node.js for Gmail MCP server
            nodejs_22
            nodePackages.npm

            # Secrets management
            agenix.packages.${system}.default
            age
            ssh-to-age

            # Utilities
            jq
            direnv

            # Gmail MCP scripts
            gmail-mcp-setup
            gmail-mcp-encrypt-token
            gmail-mcp-server
          ];

          shellHook = ''
            echo "Gmail MCP development environment"
            echo ""
            echo "Commands:"
            echo "  gmail-mcp-setup         - Decrypt credentials and set up environment"
            echo "  gmail-mcp-server        - Run the Gmail MCP server"
            echo "  gmail-mcp-encrypt-token - Encrypt token after first auth"
            echo ""
          '';
        };
      }
    ) // {
      # Export secrets.nix for agenix
      agenixSecrets = ./secrets.nix;
    };
}
