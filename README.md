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
- `CLAUDE.md`: Notes for working on this repo.

## Presenter Notes

Generate the Google Codelab from `docs/codelab.md` using the `claat` tool:

```bash
cd docs && claat export codelab.md
```

Note that `presentation.html` contains full speaker notes (press `S` during the
talk). They ship in this public repo, so anyone who clones it can read them.
