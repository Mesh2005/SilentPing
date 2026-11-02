const {createHash} = require('node:crypto');
const MAX_AGE_MS = 30000;
const DEVICE_AGE_MS = 30 * 24 * 60 * 60 * 1000;
const KINDS = new Set(['ambient', 'arrival', 'attention']);
const PATTERNS = {ambient: [0, 160], arrival: [0, 140, 180, 140], attention: [0, 350]};

function deliveryPlan({circle, signal, senderUid, nowMs}) {
  if (circle?.status !== 'connected' || !Array.isArray(circle.memberIds)
    || circle.memberIds.length !== 2 || circle.memberIds[0] !== circle.ownerUid
    || circle.memberIds[1] !== circle.guestUid || circle.ownerUid === circle.guestUid
    || !circle.memberIds.includes(senderUid) || !KINDS.has(signal?.kind)) return null;
  const sentMs = signal.sentAt?.toMillis?.();
  if (!Number.isFinite(sentMs) || sentMs > nowMs + 1000 || nowMs - sentMs >= MAX_AGE_MS) return null;
  return {
    recipientUid: circle.memberIds.find(uid => uid !== senderUid),
    kind: signal.kind,
    ttl: Math.min(MAX_AGE_MS, Math.max(1, MAX_AGE_MS - (nowMs - sentMs))),
  };
}

// Claiming before sending deliberately favors a missed push over duplicate vibration
// if the process dies after FCM accepts a message. Foreground Firestore is independent.
function createDeliveryHandler({store, messaging, now = Date.now}) {
  return async function deliver({circleId, senderUid, eventId, signal}) {
    if (!signal || !eventId) return {status: 'ignored'};
    const claimId = createHash('sha256').update(eventId).digest('hex');
    const claimed = await store.claim({circleId, senderUid, claimId, signal, nowMs: now()});
    if (!claimed) return {status: 'ignored'};
    const devices = (await store.devices(claimed.recipientUid)).filter(device =>
      device.platform === 'android' && typeof device.token === 'string'
      && device.token.length >= 30 && device.token.length <= 4096
      && Number.isFinite(device.updatedAt?.toMillis?.())
      && now() - device.updatedAt.toMillis() < DEVICE_AGE_MS);
    if (!devices.length) return {status: 'no-devices'};
    // Recheck revocation immediately before dispatch. Already accepted notifications
    // cannot be recalled if a disconnect races with FCM delivery.
    const current = await store.current(circleId, senderUid);
    const plan = deliveryPlan({...current, senderUid, nowMs: now()});
    if (!plan || !current.signal.sentAt.isEqual(signal.sentAt)) return {status: 'expired-or-revoked'};
    const response = await messaging.sendEachForMulticast({
      tokens: devices.map(device => device.token),
      notification: {title: 'SilentPing', body: 'A quiet ping is waiting.'},
      data: {circleId, kind: plan.kind},
      android: {
        priority: 'high', ttl: plan.ttl, collapseKey: circleId,
        notification: {
          channelId: `silentping_${plan.kind}_v1`, tag: circleId,
          visibility: 'private', defaultSound: false,
          vibrateTimingsMillis: PATTERNS[plan.kind],
        },
      },
    });
    for (let i = 0; i < response.responses.length; i++) {
      const code = response.responses[i].error?.code;
      if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(code)) {
        await store.removeDevice(devices[i]);
      }
    }
    return {status: 'dispatched', accepted: response.successCount, failed: response.failureCount};
  };
}
module.exports = {deliveryPlan, createDeliveryHandler};
