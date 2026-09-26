# Mailskabeloner

Tre skabeloner til **Supabase → Authentication → Emails**. Indsæt HTML'en i
feltet *Message body* på den rigtige fane, og skriv emnet i *Subject*.

| Fil | Fane i Supabase | Emne |
|---|---|---|
| `nulstil-adgangskode.html` | Reset Password | Nulstil din adgangskode til RVK Frivillig |
| `bekraeft-oprettelse.html` | Confirm signup | Bekræft din e-mail til RVK Frivillig |
| `skift-email.html` | Change Email Address | Bekræft din nye e-mailadresse |

**Kun nulstillingen sendes i dag.** Bekræftelse af e-mail er slået fra i
projektet (alle brugere bekræftes i samme sekund, de oprettes), og appen
tilbyder ikke at skifte adresse. De to andre ligger klar, hvis I slår dem til.

Overvejer I at slå e-mailbekræftelse til: det fanger tastefejl i adressen,
og en forkert adresse er ikke til at opdage senere — medlemmet kan aldrig
nulstille sin adgangskode. Prisen er et ekstra skridt ved oprettelse.

## Det, der går igen

Alle tre siger **"Du kan ikke svare på denne mail"** og henviser aktivt til
`randersvolleyball@gmail.com`. Afsenderen bliver `frivillig@randersvk.dk`,
og svar på den adresse lander ingen steder, medmindre I får lavet en
videresendelse hos jeres mailudbyder.

Variablerne (`{{ .ConfirmationURL }}`, `{{ .Email }}`, `{{ .NewEmail }}`)
udfyldes af Supabase. Lad dem stå præcis, som de er — også mellemrummene
inde i tuborgklammerne.

## Hvorfor de ser ud, som de gør

Mailklienter er ikke browsere. Gmail fjerner `<style>`-blokke, Outlook
gengiver med Word, og ingen af dem kan `flex` eller `grid`. Derfor:
tabeller til opbygningen, stilarter skrevet direkte på hvert element, ingen
eksterne skrifttyper eller billeder, og en bredde på 600px, der falder til
skærmens egen på en telefon.

Knappen er et `<a>` med baggrund — ikke et billede. Blokerer en klient
billeder, står knappen der stadig. Og under den står hele adressen som
tekst, for de klienter, der slår links fra.

Fælles stilart står i `_skabelon.md`. Ændrer du én, så ændr dem alle.

Prøv efter: `node mail-check.js` (24 checks — gengiver dem, som en klient
ville, og ser efter uudfyldte variabler og vandret rulning).
