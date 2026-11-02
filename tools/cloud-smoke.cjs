// Creates two temporary accounts, exercises production rules, then removes test data.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, createUserWithEmailAndPassword, deleteUser} = require('firebase/auth');
const {getFirestore, doc, setDoc, updateDoc, getDocFromServer, serverTimestamp, terminate} = require('firebase/firestore');
const cliAuth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
async function main() {
  const options = JSON.parse(fs.readFileSync('firebase-web.json', 'utf8'));
  const apps = [initializeApp(options, 'smoke-owner'), initializeApp(options, 'smoke-guest')];
  const users = [];
  const dbs = apps.map(app => getFirestore(app));
  const id = crypto.randomBytes(16).toString('hex');
  try {
    for (const app of apps) {
      const email = `silentping-test-${crypto.randomBytes(10).toString('hex')}@example.invalid`;
      users.push((await createUserWithEmailAndPassword(getAuth(app), email, crypto.randomBytes(24).toString('hex'))).user);
    }
    const refs = dbs.map(db => doc(db, 'circles', id));
    await setDoc(refs[0], {ownerUid: users[0].uid, guestUid: '', memberIds: [users[0].uid], status: 'waiting', createdAt: serverTimestamp()});
    if (!(await getDocFromServer(refs[1])).exists()) throw Error('Invitation unavailable');
    await updateDoc(refs[1], {guestUid: users[1].uid, memberIds: users.map(u => u.uid), status: 'pending'});
    await updateDoc(refs[0], {status: 'connected'});
    await setDoc(doc(dbs[0], 'circles', id, 'signals', users[0].uid), {kind: 'arrival', sentAt: serverTimestamp()});
    const ping = await getDocFromServer(doc(dbs[1], 'circles', id, 'signals', users[0].uid));
    if (ping.data()?.kind !== 'arrival') throw Error('Ping did not arrive');
    await setDoc(doc(dbs[1], 'circles', id, 'signals', users[1].uid), {kind: 'attention', sentAt: serverTimestamp()});
    const reply = await getDocFromServer(doc(dbs[0], 'circles', id, 'signals', users[1].uid));
    if (reply.data()?.kind !== 'attention') throw Error('Reply did not arrive');
    await updateDoc(refs[1], {status: 'closed'});
    console.log('PASS: two cloud accounts created, paired, approved, exchanged pings and disconnected.');
  } finally {
    const account = cliAuth.getGlobalDefaultAccount();
    const token = await cliAuth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
    for (const suffix of [...users.map(user => `/signals/${user.uid}`), '']) {
      const response = await fetch(`https://firestore.googleapis.com/v1/projects/silentping-app/databases/(default)/documents/circles/${id}${suffix}`, {method: 'DELETE', headers: {Authorization: `Bearer ${token.access_token}`}});
      if (!response.ok && response.status !== 404) throw Error(`Test data cleanup failed: ${response.status}`);
    }
    for (const user of users) await deleteUser(user);
    for (const db of dbs) await terminate(db);
    for (const app of apps) await deleteApp(app);
    console.log('Temporary accounts and test documents removed.');
  }
}
main().catch(error => {console.error(error.message); process.exitCode = 1;});
