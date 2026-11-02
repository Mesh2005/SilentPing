// Uses the existing Firebase CLI login; never writes or prints credentials.
const path = require('node:path');
const fs = require('node:fs');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
async function main() {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Run firebase login first.');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  async function api(url, method = 'GET', body) {
    const response = await fetch(url, {method, headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json'}, body: body ? JSON.stringify(body) : undefined});
    const data = await response.json();
    if (!response.ok) throw new Error(JSON.stringify(data));
    return data;
  }
  const base = 'https://identitytoolkit.googleapis.com/admin/v2/projects/silentping-app/config';
  const config = await api(base);
  console.log('Email/password enabled:', config.signIn?.email?.enabled ?? false);
  if (process.argv.includes('--enable-email')) {
    await api(`${base}?updateMask=signIn.email.enabled,signIn.email.passwordRequired`, 'PATCH', {signIn: {email: {enabled: true, passwordRequired: true}}});
    console.log('Email/password authentication enabled.');
  }
  const release = await api('https://firebaserules.googleapis.com/v1/projects/silentping-app/releases/cloud.firestore');
  const rules = await api(`https://firebaserules.googleapis.com/v1/${release.rulesetName}`);
  fs.writeFileSync('tools/previous-firestore-rules.json', JSON.stringify(rules, null, 2));
  console.log('Existing Firestore rules backed up for review.');
}
main().catch(error => {console.error(error.message); process.exitCode = 1;});
