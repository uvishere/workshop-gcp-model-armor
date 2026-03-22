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

- `/app`: The source code for the vulnerable (and later secured) Node.js chat application.
  - `server.js`: The Express backend and API logic.
  - `public/`: Vanilla HTML/JS frontend assets.
  - `Dockerfile`: Configuration for containerizing the app.
- `/docs`: Workshop instructions.

## Presenter Notes
If you are presenting this, you can generate a Google Codelab from the `docs/codelab.md` file using the `claat` tool:

```bash
claat export docs/codelab.md
```
