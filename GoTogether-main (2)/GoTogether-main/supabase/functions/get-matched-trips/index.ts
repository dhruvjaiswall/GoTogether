// Supabase Edge Function: get-matched-trips
// Service C: Discovery & Matching Engine
// Computes personalized match scores for trips

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface Trip {
    id: string;
    destination: string;
    start_date: string;
    end_date: string;
    budget: number | null;
    max_participants: number;
    host_id: string;
    profiles: { full_name: string; avatar_url: string | null; country: string | null; city: string | null };
}

interface TripTag {
    trip_id: string;
    tag: string;
    tag_type: "include" | "exclude";
}

interface ScoredTrip extends Trip {
    matchPercent: number;
    includeTags: string[];
    participantCount: number;
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // Create Supabase client with user's auth
        const supabaseClient = createClient(
            Deno.env.get("SUPABASE_URL") ?? "",
            Deno.env.get("SUPABASE_ANON_KEY") ?? "",
            {
                global: {
                    headers: { Authorization: req.headers.get("Authorization")! },
                },
            }
        );

        // Get current user
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
        if (userError || !user) {
            return new Response(JSON.stringify({ error: "Unauthorized" }), {
                status: 401,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        // 1. Fetch user profile
        const { data: userProfile } = await supabaseClient
            .from("profiles")
            .select("full_name, country, city")
            .eq("id", user.id)
            .single();

        // 2. Fetch user tags
        const { data: userTags } = await supabaseClient
            .from("user_tags")
            .select("tag")
            .eq("user_id", user.id);

        const userTagSet = new Set(userTags?.map((t) => t.tag) || []);

        // 3. Fetch active trips (not hosted by current user)
        const { data: trips } = await supabaseClient
            .from("trips")
            .select(`
        id, destination, start_date, end_date, budget, max_participants, host_id,
        profiles!trips_host_id_fkey (full_name, avatar_url, country)
      `)
            .eq("status", "active")
            .neq("host_id", user.id);

        if (!trips || trips.length === 0) {
            return new Response(JSON.stringify({ trips: [] }), {
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        // 4. Fetch all trip tags (include only - exclude is hidden by RLS for non-hosts)
        // We need service role to see exclude tags for filtering
        const supabaseAdmin = createClient(
            Deno.env.get("SUPABASE_URL") ?? "",
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
        );

        const tripIds = trips.map((t) => t.id);
        const { data: allTripTags } = await supabaseAdmin
            .from("trip_tags")
            .select("trip_id, tag, tag_type")
            .in("trip_id", tripIds);

        // Group tags by trip
        const tripTagsMap: Record<string, { include: string[]; exclude: string[] }> = {};
        for (const tag of allTripTags || []) {
            if (!tripTagsMap[tag.trip_id]) {
                tripTagsMap[tag.trip_id] = { include: [], exclude: [] };
            }
            tripTagsMap[tag.trip_id][tag.tag_type].push(tag.tag);
        }

        // 5. Fetch participant counts
        const { data: participantCounts } = await supabaseClient
            .from("trip_participants")
            .select("trip_id")
            .in("trip_id", tripIds)
            .eq("status", "approved");

        const countMap: Record<string, number> = {};
        for (const p of participantCounts || []) {
            countMap[p.trip_id] = (countMap[p.trip_id] || 0) + 1;
        }

        // 6. Compute scores
        const scoredTrips: ScoredTrip[] = [];

        for (const trip of trips as Trip[]) {
            const tripTags = tripTagsMap[trip.id] || { include: [], exclude: [] };

            // HARD FILTER: Check if user matches any exclude tag
            const hasExcludeMatch = tripTags.exclude.some((tag) => userTagSet.has(tag));
            if (hasExcludeMatch) {
                continue; // Skip this trip entirely
            }

            // Calculate tag score (intersection / union)
            const includeSet = new Set(tripTags.include);
            const intersection = [...userTagSet].filter((t) => includeSet.has(t)).length;
            const union = new Set([...userTagSet, ...includeSet]).size;
            const tagScore = union > 0 ? intersection / union : 0;

            // Calculate budget score (simplified - closeness to average)
            // For now, give full score if budget exists, partial if not
            const budgetScore = trip.budget ? 0.8 : 0.5;

            // Calculate date score (simplified - assume dates are available)
            const dateScore = 0.7;

            // Calculate location boost (country + city)
            let locationScore = 0.1; // Base score

            // Country match: +40% of location weight
            if (userProfile?.country && trip.profiles?.country &&
                userProfile.country.toLowerCase() === trip.profiles.country.toLowerCase()) {
                locationScore += 0.4;

                // City match: +50% of location weight (only if country matches)
                if (userProfile?.city && trip.profiles?.city &&
                    userProfile.city.toLowerCase() === trip.profiles.city.toLowerCase()) {
                    locationScore += 0.5;
                }
            }

            // Final weighted score
            const finalScore =
                tagScore * 0.5 +
                budgetScore * 0.3 +
                dateScore * 0.10 +
                locationScore * 0.10;

            scoredTrips.push({
                ...trip,
                matchPercent: Math.round(finalScore * 100),
                includeTags: tripTags.include,
                participantCount: countMap[trip.id] || 0,
            });
        }

        // 7. Sort by match percent descending
        scoredTrips.sort((a, b) => b.matchPercent - a.matchPercent);

        return new Response(JSON.stringify({ trips: scoredTrips }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});
