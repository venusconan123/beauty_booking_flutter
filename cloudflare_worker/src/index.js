const VNPAY_URL = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
const FIREBASE_SCOPE = 'https://www.googleapis.com/auth/datastore';

let cachedGoogleToken;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return cors(new Response(null, { status: 204 }));

    try {
      const url = new URL(request.url);
      let response;

      if (request.method === 'GET' && url.pathname === '/') {
        response = json({ service: 'men-hair-booking-vnpay', status: 'ok' });
      } else if (request.method === 'POST' && url.pathname === '/api/payments/create') {
        response = await createPayment(request, env);
      } else if (request.method === 'GET' && url.pathname === '/vnpay-ipn') {
        response = await handleIpn(url, env);
      } else if (request.method === 'GET' && url.pathname === '/vnpay-return') {
        response = await handleReturn(url, env);
      } else {
        response = json({ message: 'Không tìm thấy đường dẫn.' }, 404);
      }

      return cors(response);
    } catch (error) {
      console.error(error?.stack || error);
      return cors(json({ message: 'Máy chủ thanh toán gặp lỗi.' }, 500));
    }
  },
};

async function createPayment(request, env) {
  requireEnvironment(env);
  const userId = await verifyFirebaseUser(request, env);
  if (!userId) return json({ message: 'Phiên đăng nhập không hợp lệ.' }, 401);

  const body = await request.json().catch(() => ({}));
  const bookingId = String(body.bookingId || '').trim();
  if (!bookingId || bookingId.includes('/')) {
    return json({ message: 'Mã lịch hẹn không hợp lệ.' }, 400);
  }

  const bookingDocument = await getDocument(env, `bookings/${bookingId}`);
  if (!bookingDocument) return json({ message: 'Không tìm thấy lịch hẹn.' }, 404);

  const booking = decodeFields(bookingDocument.fields || {});
  if (booking.userId !== userId) {
    return json({ message: 'Bạn không có quyền thanh toán lịch này.' }, 403);
  }
  if (booking.status !== 'confirmed') {
    return json({ message: 'Lịch hẹn chưa được admin xác nhận.' }, 409);
  }
  if (booking.payment?.status === 'paid') {
    return json({ message: 'Lịch hẹn đã được thanh toán.' }, 409);
  }

  const amount = Number(booking.totalPrice || 0);
  if (!Number.isSafeInteger(amount) || amount <= 0 || !Number.isSafeInteger(amount * 100)) {
    return json({ message: 'Số tiền thanh toán không hợp lệ.' }, 400);
  }

  const orderId = `${bookingId.replace(/[^A-Za-z0-9]/g, '').slice(0, 40)}${Date.now()}`;
  const now = new Date();
  await createDocument(env, `payment_orders/${orderId}`, {
    bookingId,
    userId,
    amount,
    status: 'pending',
    createdAt: now,
  });

  await patchDocument(env, `bookings/${bookingId}`, {
    payment: {
      provider: 'vnpay',
      environment: 'sandbox',
      status: 'pending',
      amount,
      orderId,
    },
    updatedAt: now,
  }, bookingDocument.updateTime);

  const origin = new URL(request.url).origin;
  const parameters = {
    vnp_Version: '2.1.0',
    vnp_Command: 'pay',
    vnp_TmnCode: env.VNP_TMN_CODE,
    vnp_Amount: String(amount * 100),
    vnp_CurrCode: 'VND',
    vnp_TxnRef: orderId,
    vnp_OrderInfo: `Thanh toan lich hen ${bookingId}`,
    vnp_OrderType: 'other',
    vnp_Locale: 'vn',
    vnp_ReturnUrl: `${origin}/vnpay-return`,
    vnp_IpAddr: request.headers.get('CF-Connecting-IP') || '127.0.0.1',
    vnp_CreateDate: formatVietnamTime(now),
    vnp_ExpireDate: formatVietnamTime(new Date(now.getTime() + 15 * 60 * 1000)),
  };

  const query = sortedQuery(parameters);
  const secureHash = await hmacSha512(env.VNP_HASH_SECRET, query);
  return json({ paymentUrl: `${VNPAY_URL}?${query}&vnp_SecureHash=${secureHash}` });
}

async function handleIpn(url, env) {
  try {
    requireEnvironment(env);
    const result = await processVnpayResult(url, env);
    return json({ RspCode: result.code, Message: result.message });
  } catch (error) {
    console.error(error?.stack || error);
    return json({ RspCode: '99', Message: 'Unknown error' });
  }
}

async function handleReturn(url, env) {
  let successful = false;
  let message = 'Đang chờ hệ thống xác nhận giao dịch qua IPN. Hãy quay lại ứng dụng để xem trạng thái.';
  try {
    const parameters = Object.fromEntries(url.searchParams.entries());
    const receivedHash = String(parameters.vnp_SecureHash || '').toLowerCase();
    delete parameters.vnp_SecureHash;
    delete parameters.vnp_SecureHashType;
    const expectedHash = await hmacSha512(env.VNP_HASH_SECRET, sortedQuery(parameters));
    if (!receivedHash || !timingSafeEqual(receivedHash, expectedHash)) {
      message = 'Chữ ký kết quả không hợp lệ.';
    } else {
      const orderId = String(parameters.vnp_TxnRef || '');
      const orderDocument = await getDocument(env, `payment_orders/${orderId}`);
      if (orderDocument && decodeFields(orderDocument.fields || {}).status === 'paid') {
        successful = true;
        message = 'Giao dịch đã được IPN xác nhận và lưu vào hệ thống.';
      } else if (parameters.vnp_ResponseCode !== '00') {
        message = 'Thanh toán không thành công hoặc đã bị hủy.';
      }
    }
  } catch (error) {
    console.error(error?.stack || error);
    message = 'Không thể xác minh kết quả giao dịch.';
  }

  return new Response(resultPage(successful, message), {
    headers: { 'Content-Type': 'text/html; charset=UTF-8' },
  });
}

async function processVnpayResult(url, env) {
  const parameters = Object.fromEntries(url.searchParams.entries());
  const receivedHash = String(parameters.vnp_SecureHash || '').toLowerCase();
  delete parameters.vnp_SecureHash;
  delete parameters.vnp_SecureHashType;

  const expectedHash = await hmacSha512(env.VNP_HASH_SECRET, sortedQuery(parameters));
  if (!receivedHash || !timingSafeEqual(receivedHash, expectedHash)) {
    return { code: '97', message: 'Invalid signature', paid: false };
  }
  if (parameters.vnp_TmnCode !== env.VNP_TMN_CODE) {
    return { code: '97', message: 'Invalid merchant', paid: false };
  }

  const orderId = String(parameters.vnp_TxnRef || '');
  const orderDocument = await getDocument(env, `payment_orders/${orderId}`);
  if (!orderDocument) return { code: '01', message: 'Order not found', paid: false };

  const order = decodeFields(orderDocument.fields || {});
  if (Number(parameters.vnp_Amount) !== Number(order.amount) * 100) {
    return { code: '04', message: 'Invalid amount', paid: false };
  }
  if (order.status === 'paid') {
    return { code: '02', message: 'Order already confirmed', paid: true };
  }
  if (order.status !== 'pending') {
    return { code: '02', message: 'Order already processed', paid: false };
  }

  const bookingDocument = await getDocument(env, `bookings/${order.bookingId}`);
  if (!bookingDocument) return { code: '01', message: 'Booking not found', paid: false };
  const booking = decodeFields(bookingDocument.fields || {});
  if (booking.userId !== order.userId ||
      booking.status !== 'confirmed' ||
      booking.payment?.status !== 'pending' ||
      booking.payment?.orderId !== orderId ||
      Number(booking.totalPrice) !== Number(order.amount)) {
    return { code: '02', message: 'Booking no longer payable', paid: false };
  }

  const paid = parameters.vnp_ResponseCode === '00' &&
      parameters.vnp_TransactionStatus === '00';
  const now = new Date();
  const payment = {
    provider: 'vnpay',
    environment: 'sandbox',
    status: paid ? 'paid' : 'failed',
    amount: Number(order.amount),
    orderId,
    transactionNo: String(parameters.vnp_TransactionNo || ''),
    bankCode: String(parameters.vnp_BankCode || ''),
    responseCode: String(parameters.vnp_ResponseCode || ''),
  };
  if (paid) payment.paidAt = now;

  await commitPayment(env, bookingDocument, orderDocument, order, payment, now);

  return {
    code: '00',
    message: 'Confirm success',
    paid,
  };
}

async function verifyFirebaseUser(request, env) {
  const authorization = request.headers.get('Authorization') || '';
  const idToken = authorization.startsWith('Bearer ') ? authorization.slice(7) : '';
  if (!idToken) return null;

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    },
  );
  if (!response.ok) return null;
  const data = await response.json();
  return data.users?.[0]?.localId || null;
}

async function googleAccessToken(env) {
  if (cachedGoogleToken && cachedGoogleToken.expiresAt > Date.now() + 60_000) {
    return cachedGoogleToken.value;
  }

  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: FIREBASE_SCOPE,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlBytes(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`Google OAuth failed: ${await response.text()}`);
  const data = await response.json();
  cachedGoogleToken = {
    value: data.access_token,
    expiresAt: Date.now() + Number(data.expires_in || 3600) * 1000,
  };
  return cachedGoogleToken.value;
}

async function getDocument(env, path) {
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const token = await googleAccessToken(env);
  const response = await fetch(firestoreUrl(account.project_id, path), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`Firestore GET failed: ${await response.text()}`);
  return response.json();
}

async function createDocument(env, path, data) {
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const token = await googleAccessToken(env);
  const response = await fetch(`${firestoreUrl(account.project_id, path)}?currentDocument.exists=false`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: encodeFields(data) }),
  });
  if (!response.ok) throw new Error(`Firestore create failed: ${await response.text()}`);
}

async function patchDocument(env, path, data, updateTime) {
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const token = await googleAccessToken(env);
  const masks = Object.keys(data)
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  const precondition = updateTime ? `&currentDocument.updateTime=${encodeURIComponent(updateTime)}` : '';
  const response = await fetch(`${firestoreUrl(account.project_id, path)}?${masks}${precondition}`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: encodeFields(data) }),
  });
  if (!response.ok) throw new Error(`Firestore PATCH failed: ${await response.text()}`);
}

async function commitPayment(env, bookingDocument, orderDocument, order, payment, now) {
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const token = await googleAccessToken(env);
  const bookingName = bookingDocument.name;
  const orderName = orderDocument.name;
  const writes = [
    {
      update: {
        name: bookingName,
        fields: encodeFields({ payment, updatedAt: now }),
      },
      updateMask: { fieldPaths: ['payment', 'updatedAt'] },
      currentDocument: { updateTime: bookingDocument.updateTime },
    },
    {
      update: {
        name: orderName,
        fields: encodeFields({
          status: payment.status,
          responseCode: payment.responseCode,
          transactionNo: payment.transactionNo,
          updatedAt: now,
        }),
      },
      updateMask: { fieldPaths: ['status', 'responseCode', 'transactionNo', 'updatedAt'] },
      currentDocument: { updateTime: orderDocument.updateTime },
    },
  ];
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/databases/(default)/documents:commit`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ writes }),
    },
  );
  if (!response.ok) throw new Error(`Firestore commit failed: ${await response.text()}`);
}

function firestoreUrl(projectId, path) {
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents/${path.split('/').map(encodeURIComponent).join('/')}`;
}

function encodeFields(object) {
  return Object.fromEntries(Object.entries(object).map(([key, value]) => [key, encodeValue(value)]));
}

function encodeValue(value) {
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (typeof value === 'object') return { mapValue: { fields: encodeFields(value) } };
  return { stringValue: String(value) };
}

function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

function decodeValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('nullValue' in value) return null;
  if ('mapValue' in value) return decodeFields(value.mapValue.fields || {});
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decodeValue);
  return null;
}

export function sortedQuery(parameters) {
  const query = new URLSearchParams();
  Object.keys(parameters)
    .filter((key) => parameters[key] !== undefined && parameters[key] !== null && parameters[key] !== '')
    .sort()
    .forEach((key) => query.append(key, String(parameters[key])));
  return query.toString();
}

export async function hmacSha512(secret, data) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function timingSafeEqual(first, second) {
  if (first.length !== second.length) return false;
  let difference = 0;
  for (let index = 0; index < first.length; index++) {
    difference |= first.charCodeAt(index) ^ second.charCodeAt(index);
  }
  return difference === 0;
}

export function formatVietnamTime(date) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Ho_Chi_Minh',
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
    }).formatToParts(date).filter((part) => part.type !== 'literal').map((part) => [part.type, part.value]),
  );
  return `${parts.year}${parts.month}${parts.day}${parts.hour}${parts.minute}${parts.second}`;
}

function base64Url(text) {
  return base64UrlBytes(new TextEncoder().encode(text));
}

function base64UrlBytes(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function importPrivateKey(pem) {
  const base64 = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const binary = atob(base64);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    bytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function requireEnvironment(env) {
  for (const name of ['VNP_TMN_CODE', 'VNP_HASH_SECRET', 'FIREBASE_WEB_API_KEY', 'FIREBASE_SERVICE_ACCOUNT_JSON']) {
    if (!env[name]) throw new Error(`Missing environment variable: ${name}`);
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  });
}

function cors(response) {
  const headers = new Headers(response.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  return new Response(response.body, { status: response.status, headers });
}

function resultPage(successful, message) {
  const color = successful ? '#15803d' : '#b91c1c';
  const title = successful ? 'Thanh toán thành công' : 'Thanh toán chưa thành công';
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><style>body{font-family:Arial,sans-serif;background:#f7f8fc;display:grid;place-items:center;min-height:100vh;margin:0}.card{background:#fff;border-radius:18px;padding:34px;box-shadow:0 12px 36px #0002;text-align:center;max-width:480px}h1{color:${color}}p{line-height:1.5;color:#475569}</style></head><body><main class="card"><h1>${title}</h1><p>${escapeHtml(message)}</p><p>Bạn có thể đóng trang này và quay lại ứng dụng.</p></main></body></html>`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[character]);
}
