let
  # User's SSH key converted to age format
  imalison = "age1g2f76x7yzuw0t8dpuwuepe6gy8gl90r7a0ngsxekkaap8qcra3uq4jlf6r";

  # All users who can decrypt secrets
  users = [ imalison ];
in
{
  "secrets/gmail-oauth-credentials.json.age".publicKeys = users;
  "secrets/gmail-oauth-token.json.age".publicKeys = users;
}
