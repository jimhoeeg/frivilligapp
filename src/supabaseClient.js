import { createClient } from "@supabase/supabase-js";

// Prefer environment variables (set these in Vercel → Settings → Environment Variables).
// Fall back to defaults so the app keeps working locally and before env vars are set.
const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ||
  "https://mohrmjirotuabsjppank.supabase.co";

const SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vaHJtamlyb3R1YWJzanBwYW5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyNjIzODUsImV4cCI6MjA5MzgzODM4NX0.rrDdwnBbGtlxMZHHPk9X1Wrefsy47xsdurGGu7ZVHYI";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
