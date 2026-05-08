import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://mavpovmaiogfgdlwfhit.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_V7l9Gc3r2QOOsF4zQUfaWA_JIche7kh";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
