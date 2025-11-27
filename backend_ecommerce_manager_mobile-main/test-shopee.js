// test-shopee.js
const config = require('./src/config/env');
const { generateShopeeSignature } = require('./src/utils/shopeeSignature');

console.log('\nTesting Shopee Signature Generation\n');
console.log('='.repeat(70));

// Expected values
const EXPECTED_PARTNER_KEY = 'shpk456743477947656c4778665765626b4b73775654426f5277646d72684950';

console.log('\nConfiguration Verification:');
console.log(''.repeat(70));
console.log('Partner ID       :', config.shopee.partnerId);
console.log('Partner Key      :', config.shopee.partnerKey);
console.log('Key Length       :', config.shopee.partnerKey?.length, 'chars (should be 60)');
console.log('Key Matches      :', config.shopee.partnerKey === EXPECTED_PARTNER_KEY ? 'YES' : 'NO');
console.log('API URL          :', config.shopee.apiUrl);
console.log('Redirect URI     :', config.shopee.redirectUri);

// Test signature generation
console.log('\nSignature Generation Test:');
console.log(''.repeat(70));

const apiPath = '/api/v2/shop/auth_partner';
const timestamp = Math.floor(Date.now() / 1000);
const baseString = `${config.shopee.partnerId}${apiPath}${timestamp}`;

console.log('API Path         :', apiPath);
console.log('Timestamp        :', timestamp);
console.log('Base String      :', baseString);

const signature = generateShopeeSignature(
  config.shopee.partnerId,
  apiPath,
  timestamp,
  config.shopee.partnerKey
);

console.log('Generated Sign   :', signature);
console.log('Sign Length      :', signature.length, 'chars (should be 64)');

// Build test URL
console.log('\nTest Authorization URL:');
console.log(''.repeat(70));

const testUrl = `${config.shopee.apiUrl}${apiPath}?partner_id=${config.shopee.partnerId}&timestamp=${timestamp}&sign=${signature}&redirect=${encodeURIComponent(config.shopee.redirectUri)}`;

console.log('\nCopy this URL and open in browser:\n');
console.log(testUrl);
console.log('\n' + '='.repeat(70));
console.log('\nIf browser shows "wrong sign" error:');
console.log('   1. Partner Key in Shopee portal might have been regenerated');
console.log('   2. You might be using production key in test environment');
console.log('   3. Timestamp difference > 5 minutes (unlikely)\n');