# Build it, Guard it, Ship it: deck restructure

Agreed with UV on 2026-11-18.

## Why
The talk jumped from the attacks straight to three product fixes. UV wants the
room to see the attacks are part of a bigger list (OWASP), then learn a
principle before each Google Cloud product, then see how it works and a demo.

## Outline (36 slides)
1. Title · 2. Mission · 3. How the app works · 4. Agent Platform · 5. Build with google/skills · 6. Meet the bot (demo)
7. Act one: Break it · 8. Typed attacks (Passphrase, Threat; the Prompt injection chip is gone, it never leaked) · 9. Docs attack
10. OWASP Top 10 for LLM Applications 2026: "That was just two attacks", LLM01, LLM02, LLM08 light up
11. The model is not your security layer. Your security layer is around it.
12. Act two: Guard it · 13. The best way to fix it: four layers
14–17. Guardrails principle → Model Armor → how it works (animated) → protected demo
18–21. Data minimisation principle → Sensitive Data Protection → how it works → redaction demo
22–24. Least privilege / no secrets in prompts → IAM + Secret Manager → how it works
25–27. You can't fix what you can't see → Cloud Logging → how it works
28. Act three: Ship it · 29–31. Principle → Cloud Run → how it works · 32. Cloud Run demo (/whereami)
33. Takeaways · 34. Big-picture architecture · 35. Codelab QR · 36. Thank you (uvishere.com, linkedin.com/in/yuba-raj-panta)

## Calls I made
- Principle slides are separate (UV's choice), so the deck is longer than before; accepted.
- "How it works" slides animate step by step: each arrow carries a moving dot once revealed.
- The Cloud Run demo calls a new `/whereami` proxy route (service, revision, region, service account). Locally it says it's on the laptop.
- The old "Three things people skip" and "Four things to remember" slides are folded into fixes 3 and 4 and the takeaways.
