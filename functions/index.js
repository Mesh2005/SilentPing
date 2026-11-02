const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {deliveryPlan, createDeliveryHandler} = require('./delivery');
initializeApp();
const db = getFirestore();
const store = {
  async current(circleId, senderUid) {
    const circle = db.doc(`circles/${circleId}`);
    const [room, signal] = await db.getAll(circle, circle.collection('signals').doc(senderUid));
    return {circle: room.data(), signal: signal.data()};
  },
  async claim({circleId, senderUid, claimId, signal, nowMs}) {
    const circleRef = db.doc(`circles/${circleId}`);
    const signalRef = circleRef.collection('signals').doc(senderUid);
    const claimRef = db.doc(`pushDeliveries/${claimId}`);
    return db.runTransaction(async tx => {
      const [circle, current, claim] = await tx.getAll(circleRef, signalRef, claimRef);
      if (claim.exists || !current.exists || !signal.sentAt?.isEqual(current.data().sentAt)) return null;
      const plan = deliveryPlan({circle: circle.data(), signal, senderUid, nowMs});
      if (!plan) return null;
      tx.create(claimRef, {claimedAt: Timestamp.fromMillis(nowMs), expiresAt: Timestamp.fromMillis(nowMs + 86400000)});
      return plan;
    });
  },
  async devices(uid) {
    const snapshot = await db.collection('pushDevices').where('ownerUid', '==', uid).limit(20).get();
    return snapshot.docs.map(doc => ({...doc.data(), ref: doc.ref}));
  },
  async removeDevice(device) {
    await db.runTransaction(async tx => {
      const current = await tx.get(device.ref);
      if (current.exists && current.data().token === device.token) tx.delete(device.ref);
    });
  },
};
const deliver = createDeliveryHandler({store, messaging: getMessaging()});
exports.deliverPing = onDocumentWritten({
  document: 'circles/{circleId}/signals/{senderUid}',
  region: 'asia-southeast1', maxInstances: 2, concurrency: 10,
  memory: '256MiB', timeoutSeconds: 30, retry: false,
}, async event => {
  if (!event.data?.after.exists) return;
  // No UID, invitation code, token, or signal content is written to application logs.
  await deliver({...event.params, eventId: event.id, signal: event.data.after.data()});
});
