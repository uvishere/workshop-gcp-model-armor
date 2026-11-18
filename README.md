# Build It, Guard It, Ship It: Building Secure AI Apps with Model Armor

Welcome to the workshop repository for **Building Secure AI Apps with Model Armor**!

In this workshop, you will learn how to:
1. Build a functional AI chat application with Node.js and Gemini.
2. Demonstrate how LLMs are susceptible to prompt injection attacks.
3. Configure Google Cloud Model Armor to secure your application independently of the model.
4. Containerize the application and deploy it to a production environment via Cloud Run.

## Workshop Instructions

The complete step-by-step instructions for this workshop are available in the `docs/` folder as a single Markdown guide suitable for Claat Codelabs.

👉 **[Start the Workshop (Codelab Document)](docs/codelab.md)**

## Repository Structure

**If you are here to do the workshop, you only need `/app`.** Everything else is
presenter tooling — you can safely ignore it.

- `/app`: The source code for the vulnerable (and later secured) Node.js chat application.
  - `server.js`: The Express backend and API logic. You will uncomment the Model Armor steps here.
  - `public/`: Vanilla HTML/JS frontend assets.
  - `Dockerfile`: Configuration for containerizing the app.
- `/docs`: Workshop instructions (`codelab.md`).
- `setup-redaction.sh`: One-time setup for the redaction step — creates the DLP
  inspect + de-identify templates and an advanced-SDP Model Armor template.

### Presenter-only files

- `/presentation`: Everything used to deliver the live talk.
  - `presentation.html`: The talk itself. Self-contained, open it in Chrome.
  - `proxy.js` / `start.sh`: Local proxy and launcher for the live demos.
  - `deploy.sh` / `Dockerfile`: Hosts the talk and its live demos on Cloud Run.
- `CLAUDE.md`: Notes for working on this repo.

## Presenter Notes

Generate the Google Codelab from `docs/codelab.md` using the `claat` tool:

```bash
cd docs && claat export codelab.md
```

Note that `presentation.html` contains full speaker notes (press `S` during the
talk). They ship in this public repo, so anyone who clones it can read them.

## Deploying the Talk to Cloud Run

The talk also runs as a hosted copy, so you can present from any browser
without starting the proxy on your laptop.

| | |
|---|---|
| URL | https://securebank-talk-pnd5flbqwq-uc.a.run.app |
| Project / region | `gdg-secure-ai-workshop` / `us-central1` |
| Service | `securebank-talk` |
| Runs as | `securebank-talk` service account: Vertex AI User and Model Armor User only |
| Access | Password on every page (any username), stored in Secret Manager as `securebank-talk-password` |
| Scaling | Scales to zero when idle, at most 2 instances |

Get the password:

```bash
gcloud secrets versions access latest --secret securebank-talk-password --project gdg-secure-ai-workshop
```

Redeploy after editing the deck:

```bash
./presentation/deploy.sh
```

The script reads the project and Model Armor templates from `app/.env`. The
first run creates the service account, its roles and the password; later runs
just redeploy. It builds from a staging folder holding only the deck, the proxy,
`app/knowledgebase.txt` and `app/docs/`, so `app/.env` never ends up in the
image.

How it works:

- `proxy.js` serves the deck and the demo routes from the same URL. On Cloud
  Run it gets its access token from the metadata server instead of the gcloud
  CLI.
- Opened as a local file (`start.sh`), the deck still talks to
  `localhost:3001`, so presenting from your laptop is unchanged.
- An idle service takes a few seconds to wake. Open the URL a minute before
  you go on stage.

To change the password, add a new secret version and redeploy:

```bash
openssl rand -base64 18 | gcloud secrets versions add securebank-talk-password --data-file=- --project gdg-secure-ai-workshop
./presentation/deploy.sh
```

To take it down after the talk:

```bash
gcloud run services delete securebank-talk --region us-central1 --project gdg-secure-ai-workshop
```
