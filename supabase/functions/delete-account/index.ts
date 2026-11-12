// Deletes the account of the signed-in user, with all their data and files.
//
// Called by the app with the user's session. Only this function holds the
// secret key: the app can never delete an account or files by itself.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// Buckets where a user's files live, in a folder named after their id. Every
// new bucket holding user files must be added here. Tables are covered by
// "on delete cascade" from auth.users: every new table holding user data
// must have it.
const USER_BUCKETS = ["avatars", "profile-photos"];

// Storage lists at most this many entries per call.
const PAGE_SIZE = 1000;

export default {
  fetch: withSupabase(
    { auth: "user", errors: { detailed: false } },
    async (req, ctx) => {
      if (req.method !== "POST") {
        return Response.json({ error: "method_not_allowed" }, { status: 405 });
      }

      const userId = ctx.userClaims!.id;
      const storage = ctx.supabaseAdmin.storage;

      // Removes every file under prefix, subfolders included.
      async function removeFolder(bucket: string, prefix: string) {
        const files = storage.from(bucket);
        while (true) {
          const { data: entries, error } = await files.list(prefix, {
            limit: PAGE_SIZE,
          });
          if (error) throw error;

          const paths: string[] = [];
          for (const entry of entries) {
            const path = `${prefix}/${entry.name}`;
            // Folders have no id: empty them first.
            if (entry.id === null) {
              await removeFolder(bucket, path);
            } else {
              paths.push(path);
            }
          }
          if (paths.length > 0) {
            const { error: removeError } = await files.remove(paths);
            if (removeError) throw removeError;
          }
          // Removed files no longer show up: list again until a short page.
          if (entries.length < PAGE_SIZE) return;
        }
      }

      try {
        // Files first: if anything fails, the account is still there and the
        // user can retry, instead of leaving files nobody can reach.
        for (const bucket of USER_BUCKETS) {
          await removeFolder(bucket, userId);
        }

        const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId);
        // Already deleted, for example by a call whose answer was lost: the
        // goal is reached, so the app can retry safely.
        if (error && error.code !== "user_not_found") throw error;

        return Response.json({ deleted: true });
      } catch (error) {
        console.error("delete-account failed", { userId, error });
        return Response.json({ error: "deletion_failed" }, { status: 500 });
      }
    },
  ),
};
