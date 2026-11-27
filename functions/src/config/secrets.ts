import { defineSecret } from "firebase-functions/params";

// Declared only. Call functions will bind these when they are added.
export const livekitUrl = defineSecret("LIVEKIT_URL");
export const livekitApiKey = defineSecret("LIVEKIT_API_KEY");
export const livekitApiSecret = defineSecret("LIVEKIT_API_SECRET");
