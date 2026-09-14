# Supabase Backend Setup for Ever Dash

Follow these simple steps to set up player authentication and the global high score list using Supabase.

---

## 1. Create a Free Supabase Project
1. Go to [https://supabase.com](https://supabase.com) and create or sign in to your account.
2. Create a new project (e.g. `ever-dash-game`).
3. Note your **Project URL** and **Anon Key** from:
   - **Settings** -> **API** -> `Project URL` (e.g. `https://your-id.supabase.co`)
   - `Project API keys` -> `anon public` (e.g. `eyJhbGci...`)

---

## 2. Run the Database Schema
1. In your Supabase Dashboard, open the **SQL Editor** tab from the left sidebar.
2. Click **New query**.
3. Open [`supabase/schema.sql`](./schema.sql), copy its entire contents, and paste it into the editor.
4. Click **Run**.
5. This creates:
   - `public.profiles` table with public read Row Level Security (RLS)
   - Trigger to automatically register new users into `profiles`
   - `submit_score` RPC function (validates coins rate, updates high score, returns new global rank)
   - `get_my_rank` RPC function

---

## 3. (Optional) Disable Email Confirmation for Instant Play
By default, Supabase sends a confirmation email to new users. If you want players to be able to sign up and play immediately without checking their inbox:
1. In the Supabase Dashboard, go to **Authentication** -> **Providers** -> **Email**.
2. Turn **OFF** "Confirm email".
3. Click **Save**.

---

## 4. Configure Godot Client
Open [`scripts/secure/sim_constants.gd`](../scripts/secure/sim_constants.gd) and set:

```gdscript
const SUPABASE_URL: String = "https://your-id.supabase.co"
const SUPABASE_ANON_KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6..."
```

---

## 5. Verify Setup
You can test that your tables and policies are working using the Node.js verification script:

```bash
cd supabase
npm install
SUPABASE_URL="https://your-id.supabase.co" SUPABASE_ANON_KEY="your-anon-key" node setup.js
```
