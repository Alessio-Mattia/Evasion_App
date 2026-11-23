// Deletes expired posts and their photos, then the post photos no post uses.
//
// Called every 5 minutes by pg_cron (migration schedule_post_expiry) with the
// project's secret key, never by the app. Expired posts are already hidden
// by the database policies: this function only frees the space.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const BUCKET = "post-photos";

// Posts deleted per database call, and calls per run: a run stops after
// BATCH_SIZE * MAX_BATCHES posts, and the next one goes on.
const BATCH_SIZE = 500;
const MAX_BATCHES = 20;

export default {
  fetch: withSupabase(
    { auth: "secret", errors: { detailed: false } },
    async (req, ctx) => {
      if (req.method !== "POST") {
        return Response.json({ error: "method_not_allowed" }, { status: 405 });
      }

      const admin = ctx.supabaseAdmin;
      const files = admin.storage.from(BUCKET);
      let deletedPosts = 0;
      let deletedPhotos = 0;

      try {
        // Rows first: once deleted, a post is gone even if its photo cannot
        // be removed now. Such a photo becomes an orphan, removed below by a
        // later run.
        for (let batch = 0; batch < MAX_BATCHES; batch++) {
          const { data, error } = await admin.rpc("purge_expired_posts", {
            batch_size: BATCH_SIZE,
          });
          if (error) throw error;

          const paths = data as string[];
          deletedPosts += paths.length;
          if (paths.length > 0) {
            const { error: removeError } = await files.remove(paths);
            if (removeError) {
              console.error("could not remove expired post photos", {
                removeError,
              });
            } else {
              deletedPhotos += paths.length;
            }
          }
          if (paths.length < BATCH_SIZE) break;
        }

        const { data: orphans, error } = await admin.rpc(
          "list_orphan_post_photos",
          { batch_size: BATCH_SIZE },
        );
        if (error) throw error;
        if ((orphans as string[]).length > 0) {
          const { error: removeError } = await files.remove(orphans);
          if (removeError) throw removeError;
          deletedPhotos += (orphans as string[]).length;
        }

        return Response.json({ deletedPosts, deletedPhotos });
      } catch (error) {
        console.error("purge-expired-posts failed", { error });
        return Response.json({ error: "purge_failed" }, { status: 500 });
      }
    },
  ),
};
