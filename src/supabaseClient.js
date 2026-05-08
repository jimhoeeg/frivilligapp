import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://mavpovmaiogfgdlwfhit.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hdnBvdm1haW9nZmdkbHdmaGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyMzg0NDgsImV4cCI6MjA5MzgxNDQ0OH0.J6b9ZtYXtSAu3DfZEHXuNi7s2u_rQjVj6BMU6mZaN_A";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
