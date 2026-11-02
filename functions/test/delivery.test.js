const {test} = require('node:test');
const assert = require('node:assert/strict');
const {deliveryPlan, createDeliveryHandler} = require('../delivery');
const now = 200000;
const stamp = ms => ({toMillis: () => ms, isEqual: other => other?.toMillis?.() === ms});
const circle = {status: 'connected', ownerUid: 'a', guestUid: 'b', memberIds: ['a', 'b']};
const signal = {kind: 'arrival', sentAt: stamp(now - 1000)};
function fixture() {
  const claims = new Set();
  const sent = [];
  const removed = [];
  let current = {circle, signal};
  const store = {
    async claim(args) {
      const plan = deliveryPlan({...current, senderUid: args.senderUid, nowMs: args.nowMs});
      if (claims.has(args.claimId) || !plan || !current.signal.sentAt.isEqual(args.signal.sentAt)) return null;
      claims.add(args.claimId);
      return plan;
    },
    async current() { return current; },
    async devices(uid) {
      assert.equal(uid, 'b');
      return [
        {token: 'valid-token'.repeat(8), platform: 'android', updatedAt: stamp(now), id: 'valid'},
        {token: 'invalid-token'.repeat(8), platform: 'android', updatedAt: stamp(now), id: 'invalid'},
        {token: 'old-token'.repeat(8), platform: 'android', updatedAt: stamp(now - 31*86400000), id: 'old'},
        {token: 'ios-token'.repeat(8), platform: 'ios', updatedAt: stamp(now), id: 'ios'},
      ];
    },
    async removeDevice(device) { removed.push(device.id); },
  };
  const messaging = {async sendEachForMulticast(message) {
    sent.push(message);
    return {successCount: 1, failureCount: 1, responses: [{success: true}, {error: {code: 'messaging/registration-token-not-registered'}}]};
  }};
  return {store, sent, removed, handler: createDeliveryHandler({store, messaging, now: () => now}),
    change: value => {current = value;}};
}
const event = {circleId: 'circle', senderUid: 'a', eventId: 'event-1', signal};

test('only approved participants and fresh supported signals can route', () => {
  assert.equal(deliveryPlan({circle, signal, senderUid: 'a', nowMs: now}).recipientUid, 'b');
  for (const status of ['waiting', 'pending', 'closed']) {
    assert.equal(deliveryPlan({circle: {...circle, status}, signal, senderUid: 'a', nowMs: now}), null);
  }
  assert.equal(deliveryPlan({circle, signal, senderUid: 'outsider', nowMs: now}), null);
  assert.equal(deliveryPlan({circle, signal: {...signal, kind: 'unknown'}, senderUid: 'a', nowMs: now}), null);
  assert.equal(deliveryPlan({circle, signal: {...signal, sentAt: stamp(now - 30000)}, senderUid: 'a', nowMs: now}), null);
  assert.equal(deliveryPlan({circle, signal: {...signal, sentAt: stamp(now + 2000)}, senderUid: 'a', nowMs: now}), null);
  assert.equal(deliveryPlan({circle: {...circle, memberIds: ['a', 'a']}, signal, senderUid: 'a', nowMs: now}), null);
});
test('quiet short-lived notifications use the pattern channel and prune invalid tokens', async () => {
  const f = fixture();
  assert.deepEqual(await f.handler(event), {status: 'dispatched', accepted: 1, failed: 1});
  assert.equal(f.sent.length, 1);
  const message = f.sent[0];
  assert.equal(message.tokens.length, 2);
  assert.equal(message.android.ttl, 29000);
  assert.equal(message.android.notification.channelId, 'silentping_arrival_v1');
  assert.equal(message.android.notification.defaultSound, false);
  assert.deepEqual(message.android.notification.vibrateTimingsMillis, [0, 140, 180, 140]);
  assert.equal(message.android.notification.visibility, 'private');
  assert.equal(message.notification.body.includes('arrival'), false);
  assert.deepEqual(f.removed, ['invalid']);
});
test('duplicate and concurrent function events do not dispatch twice', async () => {
  const f = fixture();
  await Promise.all([f.handler(event), f.handler(event)]);
  assert.equal(f.sent.length, 1);
});
test('disconnect between claim and dispatch stops the notification', async () => {
  const f = fixture();
  f.store.devices = async () => {
    f.change({circle: {...circle, status: 'closed'}, signal});
    return [{token: 'valid-token'.repeat(8), platform: 'android', updatedAt: stamp(now)}];
  };
  assert.equal((await f.handler(event)).status, 'expired-or-revoked');
  assert.equal(f.sent.length, 0);
});
test('out-of-order signals and deletes do not dispatch', async () => {
  const f = fixture();
  assert.equal((await f.handler({...event, signal: {...signal, sentAt: stamp(now - 5000)}})).status, 'ignored');
  assert.equal((await f.handler({...event, signal: undefined})).status, 'ignored');
  assert.equal(f.sent.length, 0);
});
test('missing devices and transport failure do not generate retry duplicates', async () => {
  const f = fixture();
  f.store.devices = async () => [];
  assert.equal((await f.handler(event)).status, 'no-devices');
  const second = fixture();
  second.store.current = async () => {throw new Error('transport failure');};
  await assert.rejects(second.handler(event), /transport failure/);
  assert.equal((await second.handler(event)).status, 'ignored');
});
