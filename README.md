# .github

Shared by nvorkinn's repositories:

- `.github/workflows/`: reusable workflows (the Global PR Status checks).
- `actions/vaultwarden-secrets`: a composite action that fetches a deploy's secrets from Vaultwarden into `.env` files,
  from the repository's own secrets map. See its `action.yml` for the inputs. Items are named by their bare variable
  and told apart by collection, so a secret several projects use is one item in each project's collection.
