# Vejledning til nye medlemmer

Indholdet til den mail, der sendes ud til klubbens medlemmer, og de
skærmbilleder der hører til.

| Fil | Hvad |
|---|---|
| `mail-kom-godt-i-gang.html` | Mailen, sat op og klar. Åbn den i en browser. |
| `mail-kom-godt-i-gang.txt` | Samme tekst i ren tekst, hvis du hellere vil skrive den selv. |
| `01` … `11-*.jpg` | De elleve skærmbilleder, i den rækkefølge de står i mailen. |

## Sådan sender du den

1. Åbn `mail-kom-godt-i-gang.html` i en browser (dobbeltklik på filen).
2. Tryk **Ctrl/Cmd + A** og **Ctrl/Cmd + C**.
3. Åbn en ny mail i Gmail og tryk **Ctrl/Cmd + V**.
   Gmail henter billederne med af sig selv og lægger dem ind i mailen.
4. Emne: **Kom godt i gang med RVK Frivillig**

Læg medlemmerne i **Bcc**, ikke i Til. Ellers får alle 26 hinandens
e-mailadresser, og det er en videregivelse af personoplysninger, ingen har
bedt om.

Gmail klipper en mail over, hvis selve teksten fylder over ~100 kB. Det gør
denne ikke — billederne tæller som vedhæftninger, ikke som tekst.

## Skærmbillederne

De er taget i den rigtige app, ikke tegnet. Personen hedder "Mette Sørensen"
og er opdigtet; opgaverne og teksterne er klubbens egne. **Der er ingen
rigtige medlemmers navne, e-mail eller telefonnumre i billederne** — det er
med vilje, for en vejledning bliver videresendt.

Skal de tages om — fordi appen har ændret sig — ligger opskriften i
`skud.js` (i den mappe, billederne blev lavet i). Den starter en browser mod
en lokal udgave af appen med opdigtede data og knipser elleve skærme.

## Tallene i mailen

Mailen siger 200 point og 400 kr., og at efteråret er gratis. Det er hentet
fra klubbens egne indstillinger den 27. september 2026:

| Indstilling | Værdi |
|---|---|
| `point_goal` | 200 |
| `contribution_kr` | 400 |
| `auto_confirm_days` | 7 (deraf "godkendes af sig selv efter en uge") |

Ændrer bestyrelsen nogen af dem under **Admin → Indstillinger**, skal
mailen rettes tilsvarende, før den sendes igen.
