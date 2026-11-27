import {
  AccessToken,
  TokenVerifier,
  TrackSource,
  WebhookReceiver,
} from "livekit-server-sdk";

const apiKey = "test-key";
const apiSecret = "test-secret";
const ttlSeconds = 15 * 60;

describe("livekit access token spike", () => {
  it("grants one room, microphone only, for 15 minutes", async () => {
    const token = new AccessToken(apiKey, apiSecret, {
      identity: "test-uid",
      ttl: ttlSeconds,
    });
    token.addGrant({
      roomJoin: true,
      room: "test-room",
      canPublish: true,
      canPublishSources: [TrackSource.MICROPHONE],
      canSubscribe: true,
      canPublishData: false,
    });

    const jwt = await token.toJwt();
    const claims = await new TokenVerifier(apiKey, apiSecret).verify(jwt);
    const video = claims.video;

    expect(claims.sub).toBe("test-uid");
    expect(video?.roomJoin).toBe(true);
    expect(video?.room).toBe("test-room");
    expect(video?.canPublish).toBe(true);
    expect(video?.canPublishSources).toEqual(["microphone"]);
    expect(video?.canSubscribe).toBe(true);
    expect(video?.canPublishData).toBe(false);
    expect(claims.exp).toEqual(expect.any(Number));
    expect(claims.nbf).toEqual(expect.any(Number));
    expect((claims.exp ?? 0) - (claims.nbf ?? 0)).toBe(ttlSeconds);
  });

  it("constructs a WebhookReceiver", () => {
    const receiver = new WebhookReceiver(apiKey, apiSecret);
    expect(receiver).toBeInstanceOf(WebhookReceiver);
  });
});
