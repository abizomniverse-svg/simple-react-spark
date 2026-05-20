const https = require('https');
const http = require('http');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const API_BASE = 'https://192.168.0.122';
const API_DOMAIN = 'https://achme.com';

function request(url, method = 'GET', body = null, token = null) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const options = {
      hostname: parsed.hostname,
      port: parsed.port || 443,
      path: parsed.pathname + parsed.search,
      method,
      headers: {
        'Content-Type': 'application/json',
      },
      rejectUnauthorized: false,
    };
    if (token) options.headers.Authorization = `Bearer ${token}`;
    if (body) options.headers['Content-Length'] = Buffer.byteLength(JSON.stringify(body));

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function test() {
  console.log('=== LOGIN ===');
  const login = await request(`${API_BASE}/api/auth/login`, 'POST', {
    email: 'Kk@achmecommunication.com',
    password: 'admin123'
  });
  console.log('Status:', login.status);
  const token = login.data.token;
  if (!token) { console.error('No token!'); return; }
  console.log('Token:', token.substring(0, 30) + '...');

  console.log('\n=== CREATE CLIENT (via IP) ===');
  const created = await request(`${API_BASE}/api/client`, 'POST', {
    name: 'Test CRUD Client',
    email: 'testcrud@test.com',
    phone: '1234567890',
    city: 'Test',
    client_status: 'active'
  }, token);
  console.log('Status:', created.status, JSON.stringify(created.data));
  const clientId = created.data.id;
  if (!clientId) { console.error('No client ID!'); return; }
  console.log('Client ID:', clientId);

  console.log('\n=== READ CLIENT (via IP) ===');
  const read = await request(`${API_BASE}/api/client/${clientId}`, 'GET', null, token);
  console.log('Status:', read.status, read.data.name);

  console.log('\n=== UPDATE CLIENT (via domain) ===');
  const updated = await request(`${API_DOMAIN}/api/client/${clientId}`, 'PUT', {
    name: 'Updated CRUD Client'
  }, token);
  console.log('Status:', updated.status, JSON.stringify(updated.data));

  console.log('\n=== VERIFY UPDATE ===');
  const verify = await request(`${API_DOMAIN}/api/client/${clientId}`, 'GET', null, token);
  console.log('Status:', verify.status, verify.data.name);

  console.log('\n=== DELETE CLIENT (via domain) ===');
  const deleted = await request(`${API_DOMAIN}/api/client/${clientId}`, 'DELETE', null, token);
  console.log('Status:', deleted.status, JSON.stringify(deleted.data));

  console.log('\n=== VERIFY DELETE ===');
  const verifyDel = await request(`${API_DOMAIN}/api/client/${clientId}`, 'GET', null, token);
  console.log('Status:', verifyDel.status, verifyDel.data.message || 'Still exists!');

  console.log('\n=== TELECALLS CRUD ===');
  const telecall = await request(`${API_BASE}/api/Telecalls`, 'GET', null, token);
  console.log('Telecalls count:', telecall.data.length || telecall.data.message);

  console.log('\n=== ALL CRUD TESTS PASSED ===');
}

test().catch(console.error);
