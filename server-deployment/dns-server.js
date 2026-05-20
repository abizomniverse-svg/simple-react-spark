/**
 * Achme Enterprise Local DNS Server
 * =================================
 * A native, zero-dependency Node.js DNS Forwarder/Proxy.
 * Intercepts lookups for achme.com, api.achme.com, and subdomains, resolving them 
 * dynamically to the server's current local LAN IP address. 
 * Relays all other lookups to public DNS (8.8.8.8) to keep client devices online.
 * 
 * Port 53 requires Administrator on Windows. Falls back to 5353 if unavailable.
 */

const dgram = require('dgram');
const os = require('os');

const PREFERRED_PORT = 53;
const FALLBACK_PORT = 5353;
const PUBLIC_DNS = '8.8.8.8';

function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        if (iface.address.startsWith('192.168.') || 
            iface.address.startsWith('10.') || 
            iface.address.startsWith('172.')) {
          return iface.address;
        }
      }
    }
  }
  return '127.0.0.1';
}

let activeServerIP = getLocalIP();
console.log(`[DNS] Detected Active Local LAN IP: ${activeServerIP}`);

setInterval(() => {
  const currentIP = getLocalIP();
  if (currentIP !== activeServerIP) {
    console.log(`[DNS] Server LAN IP shifted from ${activeServerIP} to ${currentIP}`);
    activeServerIP = currentIP;
  }
}, 15000);

function parseDomain(buffer) {
  try {
    let offset = 12;
    let domainParts = [];
    while (true) {
      let len = buffer[offset];
      if (len === 0) break;
      if (offset + 1 + len > buffer.length) {
        return null;
      }
      domainParts.push(buffer.toString('utf8', offset + 1, offset + 1 + len));
      offset += len + 1;
    }
    return {
      domain: domainParts.join('.').toLowerCase(),
      endOffset: offset + 1
    };
  } catch (err) {
    return null;
  }
}

const server = dgram.createSocket('udp4');

server.on('message', (msg, rinfo) => {
  const parsed = parseDomain(msg);
  if (!parsed) {
    relayToPublicDNS(msg, rinfo);
    return;
  }

  const { domain, endOffset } = parsed;
  
  if (endOffset + 4 > msg.length) {
    relayToPublicDNS(msg, rinfo);
    return;
  }

  const type = msg.readUInt16BE(endOffset);
  const clazz = msg.readUInt16BE(endOffset + 2);

  const isAchmeDomain = (domain === 'achme.com' || domain.endsWith('.achme.com'));

  if (isAchmeDomain && (type === 1 || type === 255)) {
    console.log(`[DNS] Query from ${rinfo.address}:${rinfo.port} for '${domain}' -> ${activeServerIP}`);
    
    try {
      const header = Buffer.alloc(12);
      header.writeUInt16BE(msg.readUInt16BE(0), 0);
      header.writeUInt16BE(0x8180, 2);
      header.writeUInt16BE(1, 4);
      header.writeUInt16BE(1, 6);
      header.writeUInt16BE(0, 8);
      header.writeUInt16BE(0, 10);

      const questionSection = msg.slice(12, endOffset + 4);

      const answer = Buffer.alloc(16);
      answer.writeUInt16BE(0xc00c, 0);
      answer.writeUInt16BE(1, 2);
      answer.writeUInt16BE(1, 4);
      answer.writeUInt32BE(60, 6);
      answer.writeUInt16BE(4, 10);

      const ipBytes = activeServerIP.split('.').map(Number);
      answer.writeUInt8(ipBytes[0], 12);
      answer.writeUInt8(ipBytes[1], 13);
      answer.writeUInt8(ipBytes[2], 14);
      answer.writeUInt8(ipBytes[3], 15);

      const responseBuffer = Buffer.concat([header, questionSection, answer]);
      server.send(responseBuffer, rinfo.port, rinfo.address);
    } catch (err) {
      console.error(`[DNS] Failed to construct response: ${err.message}`);
      relayToPublicDNS(msg, rinfo);
    }
  } else {
    relayToPublicDNS(msg, rinfo, domain);
  }
});

function relayToPublicDNS(msg, rinfo, domainName = 'External Domain') {
  const proxySocket = dgram.createSocket('udp4');
  
  proxySocket.send(msg, 0, msg.length, 53, PUBLIC_DNS, (err) => {
    if (err) {
      console.error(`[DNS] Error proxying ${domainName} to ${PUBLIC_DNS}: ${err.message}`);
      proxySocket.close();
    }
  });

  proxySocket.on('message', (responseMsg) => {
    server.send(responseMsg, rinfo.port, rinfo.address, (err) => {
      if (err) {
        console.error(`[DNS] Error returning DNS packet to client: ${err.message}`);
      }
      proxySocket.close();
    });
  });

  proxySocket.on('error', (err) => {
    console.error(`[DNS] Proxy Socket Error: ${err.message}`);
    proxySocket.close();
  });

  setTimeout(() => {
    try { proxySocket.close(); } catch (e) {}
  }, 4000);
}

// Try preferred port first, fallback to alternate
function tryBind(port) {
  return new Promise((resolve, reject) => {
    const s = dgram.createSocket('udp4');
    s.on('error', (err) => {
      s.close();
      reject(err);
    });
    s.bind(port, () => {
      resolve(s);
    });
  });
}

async function startDNS() {
  let boundPort;
  try {
    await tryBind(PREFERRED_PORT);
    boundPort = PREFERRED_PORT;
  } catch (err) {
    console.log(`[DNS] Port ${PREFERRED_PORT} unavailable (requires Administrator). Trying fallback port ${FALLBACK_PORT}...`);
    try {
      await tryBind(FALLBACK_PORT);
      boundPort = FALLBACK_PORT;
    } catch (err2) {
      console.error(`[CRITICAL] Cannot bind to port ${PREFERRED_PORT} or ${FALLBACK_PORT}: ${err2.message}`);
      process.exit(1);
    }
  }

  server.on('listening', () => {
    const address = server.address();
    console.log(`============================================================`);
    console.log(`          ACHME ENTERPRISE PRIVATE DNS SERVER ACTIVE        `);
    console.log(`============================================================`);
    console.log(`[OK] Server listening on UDP port ${address.port}`);
    console.log(`[OK] LAN devices can set DNS server to: ${activeServerIP}`);
    if (boundPort !== PREFERRED_PORT) {
      console.log(`[NOTE] Running on fallback port ${boundPort}. Port ${PREFERRED_PORT} requires Administrator.`);
    }
    console.log(`[OK] All requests for 'achme.com' will route directly to this PC.`);
    console.log(`============================================================\n`);
  });

  server.on('error', (err) => {
    console.error(`[CRITICAL] DNS Server error: ${err.message}`);
    process.exit(1);
  });

  server.bind(boundPort);
}

startDNS();
