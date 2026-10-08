# Solution

The finished workshop app: every step done, and a knowledgebase with the credentials removed.

## Catch up

Fallen behind? From the `app/` folder:

```bash
cp ../solution/server.js ../solution/knowledgebase.txt .
```

Then carry on from the step you were on. Your `.env` and `node_modules` stay as they are.

The solution expects the full `.env` (`GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, `SECUREBANK_DOCS_BUCKET`, `MODEL_ARMOR_TEMPLATE`) and `ADMIN_API_KEY` exported from Secret Manager (Step 05). Without `MODEL_ARMOR_TEMPLATE` it stops at startup and says so.

## Run it in place

`node solution/server.js` from the repo root also works: it uses `app/`'s `public/`, `docs/`, `.env` and `node_modules`.
