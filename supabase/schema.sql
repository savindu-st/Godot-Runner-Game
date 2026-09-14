-- =============================================================================
-- EVER DASH (Godot Runner Game) - Supabase Database Schema
-- Distance-Based Leaderboard
-- Run this in the Supabase Dashboard -> SQL Editor
-- =============================================================================

-- 1. Create or update the public profiles table linked to auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    best_distance INT NOT NULL DEFAULT 0,  -- Primary rank metric (meters)
    best_coins INT NOT NULL DEFAULT 0,     -- Secondary metric
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Ensure best_distance column exists if table was already created
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS best_distance INT NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS best_coins INT NOT NULL DEFAULT 0;

-- Index for instant distance leaderboard lookups
CREATE INDEX IF NOT EXISTS idx_profiles_best_distance_desc 
    ON public.profiles(best_distance DESC, updated_at ASC);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow anyone (anonymous or authenticated) to view public profiles & high scores
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" 
    ON public.profiles 
    FOR SELECT 
    USING (true);

-- Allow users to update their own profile username
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" 
    ON public.profiles 
    FOR UPDATE 
    USING (auth.uid() = id);

-- 3. Automatic Profile Creation Trigger
-- When a user registers via Supabase Auth with metadata: { "username": "..." }
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public
AS $$
DECLARE
    v_username TEXT;
BEGIN
    -- Extract username from raw_user_meta_data or fallback to email prefix
    v_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        split_part(NEW.email, '@', 1)
    );

    -- Ensure non-empty username
    IF v_username IS NULL OR trim(v_username) = '' THEN
        v_username := 'Runner_' || substring(NEW.id::text from 1 for 6);
    END IF;

    -- Avoid duplicate username conflict by appending short unique suffix if needed
    IF EXISTS (SELECT 1 FROM public.profiles WHERE username = v_username) THEN
        v_username := v_username || '_' || substring(NEW.id::text from 1 for 4);
    END IF;

    INSERT INTO public.profiles (id, username, best_distance, best_coins, created_at, updated_at)
    VALUES (NEW.id, v_username, 0, 0, now(), now())
    ON CONFLICT (id) DO UPDATE 
    SET username = EXCLUDED.username,
        updated_at = now();

    RETURN NEW;
END;
$$;

-- Drop trigger if it exists and recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Secure Score Submission RPC Function (Distance-Based)
-- Validates reasonable speed/distance rate, updates best_distance, and returns updated rank
CREATE OR REPLACE FUNCTION public.submit_score(
    p_distance INT,
    p_duration_sec FLOAT DEFAULT 0.0,
    p_coins INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_current_best_dist INT := 0;
    v_new_best_dist INT := 0;
    v_current_best_coins INT := 0;
    v_new_best_coins INT := 0;
    v_rank INT := 0;
    v_max_allowed_dist INT;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_distance < 0 THEN
        p_distance := 0;
    END IF;

    IF p_coins < 0 THEN
        p_coins := 0;
    END IF;

    -- Sanity check: Max running speed is at most ~50 units/sec (25 meters/sec)
    -- Allow generous slack buffer for networking / frames
    IF p_duration_sec > 0.5 THEN
        v_max_allowed_dist := CEIL(p_duration_sec * 60.0) + 100;
        IF p_distance > v_max_allowed_dist THEN
            p_distance := v_max_allowed_dist;
        END IF;
    END IF;

    -- Get current records for this user
    SELECT COALESCE(best_distance, 0), COALESCE(best_coins, 0)
    INTO v_current_best_dist, v_current_best_coins
    FROM public.profiles
    WHERE id = v_user_id;

    v_new_best_dist := GREATEST(v_current_best_dist, p_distance);
    v_new_best_coins := GREATEST(v_current_best_coins, p_coins);

    -- Atomically update profile
    UPDATE public.profiles
    SET best_distance = v_new_best_dist,
        best_coins = v_new_best_coins,
        updated_at = v_now
    WHERE id = v_user_id;

    -- Calculate rank based on DISTANCE (number of players with greater distance + 1)
    SELECT COUNT(*) + 1 INTO v_rank
    FROM public.profiles
    WHERE best_distance > v_new_best_dist;

    RETURN jsonb_build_object(
        'accepted', true,
        'submitted_distance', p_distance,
        'best_distance', v_new_best_dist,
        'submitted_coins', p_coins,
        'best_coins', v_new_best_coins,
        'rank', v_rank,
        'is_new_best', (p_distance > v_current_best_dist)
    );
END;
$$;

-- 5. Helper RPC to get current authenticated user's rank & best distance
CREATE OR REPLACE FUNCTION public.get_my_rank()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_username TEXT;
    v_best_dist INT := 0;
    v_best_coins INT := 0;
    v_rank INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('authenticated', false);
    END IF;

    SELECT username, best_distance, best_coins 
    INTO v_username, v_best_dist, v_best_coins
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_username IS NULL THEN
        RETURN jsonb_build_object('authenticated', true, 'rank', 0, 'best_distance', 0, 'best_coins', 0);
    END IF;

    -- Rank by distance
    SELECT COUNT(*) + 1 INTO v_rank
    FROM public.profiles
    WHERE best_distance > v_best_dist;

    RETURN jsonb_build_object(
        'authenticated', true,
        'username', v_username,
        'best_distance', v_best_dist,
        'best_coins', v_best_coins,
        'rank', v_rank
    );
END;
$$;

-- Grant execute permissions to anon and authenticated roles
GRANT EXECUTE ON FUNCTION public.submit_score(INT, FLOAT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_rank() TO authenticated;
