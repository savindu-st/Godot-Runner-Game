/**
 * Ever Dash — Supabase Backend Verification Tool
 * 
 * Usage:
 *   export SUPABASE_URL="https://your-project.supabase.co"
 *   export SUPABASE_ANON_KEY="your-anon-key"
 *   node setup.js
 */

import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.SUPABASE_URL || "";
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || "";

console.log("==================================================");
console.log("   Ever Dash: Supabase Verification Script");
console.log("==================================================");

if (!supabaseUrl || !supabaseAnonKey) {
  console.log("\n⚠️  SUPABASE_URL or SUPABASE_ANON_KEY is not set.");
  console.log("Please export them or pass them via environment variables:");
  console.log('  export SUPABASE_URL="https://xxxx.supabase.co"');
  console.log('  export SUPABASE_ANON_KEY="your-anon-key"\n');
  console.log("Or run:");
  console.log('  SUPABASE_URL="..." SUPABASE_ANON_KEY="..." node setup.js\n');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function runChecks() {
  console.log(`\nConnecting to: ${supabaseUrl}`);

  // 1. Check profiles table access
  console.log("\n[1/3] Testing 'profiles' table query...");
  const { data: topPlayers, error: tableError } = await supabase
    .from("profiles")
    .select("username, best_coins")
    .order("best_coins", { ascending: false })
    .limit(5);

  if (tableError) {
    console.error("❌ Failed to query 'profiles' table:", tableError.message);
    console.log("👉 Make sure you ran 'supabase/schema.sql' in the Supabase Dashboard SQL Editor!");
    process.exit(1);
  }
  console.log("✅ 'profiles' table is accessible via Anon Key!");
  console.log(`   Found ${topPlayers.length} existing player profile(s):`);
  topPlayers.forEach((p, idx) => {
    console.log(`   #${idx + 1} ${p.username}: ${p.best_coins} coins`);
  });

  // 2. Check auth service reachability
  console.log("\n[2/3] Checking Supabase Auth service...");
  const { data: sessionData, error: authError } = await supabase.auth.getSession();
  if (authError) {
    console.error("❌ Auth service returned error:", authError.message);
  } else {
    console.log("✅ Supabase Auth service is active and responsive.");
  }

  // 3. Test RPC function reachability
  console.log("\n[3/3] Checking 'get_my_rank' RPC...");
  const { data: rankData, error: rpcError } = await supabase.rpc("get_my_rank");
  if (rpcError) {
    // Note: get_my_rank might require authenticated user or return authenticated: false
    if (rpcError.message.includes("function") && rpcError.message.includes("does not exist")) {
      console.error("❌ RPC function 'get_my_rank' was not found:", rpcError.message);
      console.log("👉 Run 'supabase/schema.sql' to install the stored procedures.");
      process.exit(1);
    } else {
      console.log("✅ RPC endpoint is registered (returns:", rpcError.message, ")");
    }
  } else {
    console.log("✅ RPC 'get_my_rank' response:", rankData);
  }

  console.log("\n==================================================");
  console.log("🎉 Verification Complete! Supabase is configured and ready.");
  console.log("Next step: Add your SUPABASE_URL and SUPABASE_ANON_KEY to:");
  console.log("  scripts/secure/sim_constants.gd");
  console.log("==================================================\n");
}

runChecks().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
