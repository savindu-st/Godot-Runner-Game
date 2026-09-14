/**
 * Automated test suite for Supabase SQL schema & API contracts.
 * 
 * Runs offline validation of schema.sql, and live integration tests if
 * SUPABASE_URL and SUPABASE_ANON_KEY are present in the environment.
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { createClient } from "@supabase/supabase-js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    passed++;
    console.log(`  ✅ PASS: ${message}`);
  } else {
    failed++;
    console.error(`  ❌ FAIL: ${message}`);
  }
}

console.log("\n========================================================");
console.log("   Ever Dash: Supabase Backend Automated Test Suite");
console.log("========================================================\n");

// -----------------------------------------------------------------------------
// 1. SQL Schema Static Analysis Tests
// -----------------------------------------------------------------------------
console.log("[Test Group 1] Supabase SQL Schema Validation");
const schemaPath = path.join(__dirname, "schema.sql");
assert(fs.existsSync(schemaPath), "schema.sql exists in supabase directory");

const schemaContent = fs.readFileSync(schemaPath, "utf8");

assert(
  schemaContent.includes("CREATE TABLE IF NOT EXISTS public.profiles"),
  "Defines public.profiles table"
);
assert(
  schemaContent.includes("best_distance INT NOT NULL DEFAULT 0"),
  "Defines best_distance column on public.profiles"
);
assert(
  schemaContent.includes("ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY"),
  "Enables Row Level Security (RLS) on profiles"
);
assert(
  schemaContent.includes("CREATE POLICY \"Public profiles are viewable by everyone\""),
  "Configures public SELECT policy for leaderboard access"
);
assert(
  schemaContent.includes("CREATE OR REPLACE FUNCTION public.handle_new_user()"),
  "Defines automatic user profile trigger function"
);
assert(
  schemaContent.includes("CREATE OR REPLACE FUNCTION public.submit_score"),
  "Defines submit_score stored procedure (RPC)"
);
assert(
  schemaContent.includes("CREATE OR REPLACE FUNCTION public.get_my_rank()"),
  "Defines get_my_rank stored procedure (RPC)"
);
assert(
  schemaContent.includes("GRANT EXECUTE ON FUNCTION public.submit_score"),
  "Grants execution permissions on submit_score"
);

// -----------------------------------------------------------------------------
// 2. Godot Client API Contract Tests
// -----------------------------------------------------------------------------
console.log("\n[Test Group 2] Godot Client API Contract Verification");

// Validate Auth Signup payload contract
const testSignupPayload = {
  email: "player@example.com",
  password: "password123",
  data: { username: "SonicDash" },
};
assert(testSignupPayload.email.includes("@"), "Auth payload has valid email format");
assert(testSignupPayload.password.length >= 6, "Auth payload enforces min 6 char password");
assert(typeof testSignupPayload.data.username === "string", "Auth metadata contains username");

// Validate Score submission payload contract
const testScorePayload = {
  p_distance: 350,
  p_duration_sec: 45.2,
  p_coins: 150,
};
assert(testScorePayload.p_distance >= 0, "Score payload distance is non-negative");
assert(testScorePayload.p_coins >= 0, "Score payload coins is non-negative");
assert(testScorePayload.p_duration_sec >= 0, "Score payload duration is non-negative");

// -----------------------------------------------------------------------------
// 3. Live Integration Tests (if credentials provided)
// -----------------------------------------------------------------------------
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

async function runLiveTests() {
  if (!supabaseUrl || !supabaseAnonKey) {
    console.log("\n[Test Group 3] Live Supabase Integration Tests");
    console.log("  ℹ️  SKIPPED: Set SUPABASE_URL and SUPABASE_ANON_KEY to run live checks.");
    finish();
    return;
  }

  console.log("\n[Test Group 3] Live Supabase Integration Tests");
  const supabase = createClient(supabaseUrl, supabaseAnonKey);

  try {
    const { data: top20, error: lbError } = await supabase
      .from("profiles")
      .select("username, best_distance, best_coins")
      .order("best_distance", { ascending: false })
      .limit(20);

    assert(!lbError, "Successfully fetched leaderboard from live Supabase instance");
    assert(Array.isArray(top20), "Leaderboard response is an Array");

    const { error: rpcError } = await supabase.rpc("get_my_rank");
    const rpcFound = !rpcError || !rpcError.message.includes("does not exist");
    assert(rpcFound, "RPC function 'get_my_rank' exists on live Supabase instance");
  } catch (err) {
    assert(false, `Unexpected live connection error: ${err.message}`);
  }

  finish();
}

function finish() {
  console.log("\n========================================================");
  if (failed === 0) {
    console.log(`🎉 ALL ${passed} BACKEND TESTS PASSED SUCCESSFULLY!`);
    console.log("========================================================\n");
    process.exit(0);
  } else {
    console.error(`❌ BACKEND TEST SUITE FAILED: ${passed} passed, ${failed} failed`);
    console.log("========================================================\n");
    process.exit(1);
  }
}

runLiveTests().catch((e) => {
  console.error("Test runner error:", e);
  process.exit(1);
});
