# Historik — kør ikke disse filer

Sådan blev databasen bygget, før der kom styr på rækkefølgen. Filerne er
gemt for historikkens skyld, og fordi flere af dem faktisk blev kørt på
produktionsdatabasen.

**Kør dem ikke igen.** De blander skema og adgangsregler sammen, og flere af
dem gendanner regler, der siden er strammet. Kører du fx `supabase_setup.sql`
igen, genskaber du denne linje:

```sql
create policy "profiles_select" on public.profiles for select using (true);
```

Det er politikken, der gjorde hele medlemslisten — navne, e-mails og
telefonnumre — læsbar uden at være logget ind.

## Hvad du skal bruge i stedet

`supabase/migrations/` i navnerækkefølge. De er skrevet, så de kan køres
flere gange uden at gøre skade, og så de tilsammen er nok:

| Fil | Indhold |
|---|---|
| `20260101000000_baseline.sql` | Tabeller og indekser. Intet andet. |
| `20260910120000_launch_hardening.sql` | Adgang til medlemsdata, godkendelse, pointregnskab, bytte, beskeder |
| `20260918100000_task_completion.sql` | Point først når en tjans er bekræftet |
| `20260918140000_auto_confirm.sql` | Automatisk bekræftelse efter 7 dage |
| `20260918160000_cleanup_orphans.sql` | Fjerner efterladte pointfunktioner |
| `20260919080000_policies_from_legacy.sql` | De adgangsregler, der før kun lå her i mappen |
| `20260919090000_points_follow_task.sql` | Point følger med, når en opgaves værdi ændres |

## En enkelt undtagelse

`supabase_avatars_teams.sql` indeholder en liste over standardhold. Skal I
have hold ind i en tom database, så brug `supabase/seed.sql` i stedet — den
er skrevet til at blive rettet til klubbens rigtige hold.
