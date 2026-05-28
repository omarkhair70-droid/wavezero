export interface Env {
  MANIFEST_BUCKET: R2Bucket;
  MANIFEST_SIGNING_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return Response.json({ status: "ok", service: "wavezero-edge-worker" });
    }

    // TODO: Cloudflare R2 signed manifests: validate signatures, enforce expiry,
    // and stream HLS/CMAF manifests and segments from MANIFEST_BUCKET.
    return new Response("signed manifest access placeholder", { status: 501 });
  },
};
