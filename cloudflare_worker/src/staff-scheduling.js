import staffModule from '../../functions/src/staff.js';
import schedulingModule from '../../functions/src/scheduling.js';
import reviewRatingModule from '../../functions/src/review_ratings.js';
import { RestFirestore, rosterHints } from './firestore-rest.js';

const PROJECT = 'men-hair-booking';
const METHODS = new Set(['linkStaffAccount', 'createStaffAccount', 'setStaffAccountActive',
  'saveRoster', 'saveShifts', 'cancelShift', 'swapShifts', 'createBooking',
  'updateBookingServices', 'changeBookingStatus', 'recordBookingPayment',
  'getAvailability', 'listBookableStaff', 'releaseStaleSlots', 'getBarberRatings']);
const STATUS = { 'invalid-argument': 400, unauthenticated: 401, 'permission-denied': 403,
  'not-found': 404, 'already-exists': 409, 'failed-precondition': 412, 'resource-exhausted': 429 };
const json = (body, status = 200) => new Response(JSON.stringify(body), { status,
  headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

function userRecord(value) {
  return { uid: value.localId, email: value.email, displayName: value.displayName || '',
    emailVerified: value.emailVerified === true, disabled: value.disabled === true };
}
export class RestAuth {
  constructor({ projectId, tokenProvider, baseUrl = 'https://identitytoolkit.googleapis.com/v1', fetchImpl = fetch }) {
    this.api = `${baseUrl}/projects/${projectId}/accounts`; this.tokenProvider = tokenProvider;
    this.fetchImpl = fetchImpl.bind(globalThis);
  }
  async request(operation, body) {
    const response = await this.fetchImpl(`${this.api}${operation ? ':' + operation : ''}`, { method: 'POST',
      headers: { Authorization: `Bearer ${await this.tokenProvider()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(15000) });
    const result = await response.json();
    if (!response.ok) {
      const reason = result.error?.message?.split(' : ')[0];
      const codes = { EMAIL_EXISTS: 'auth/email-already-exists', DUPLICATE_LOCAL_ID: 'auth/uid-already-exists',
        USER_NOT_FOUND: 'auth/user-not-found', EMAIL_NOT_FOUND: 'auth/user-not-found',
        INVALID_PASSWORD: 'auth/invalid-password', INVALID_EMAIL: 'auth/invalid-email' };
      const error = new Error('Không thể xử lý tài khoản Firebase Authentication.');
      error.code = codes[reason] || 'auth/internal-error';
      error.upstreamStatus = response.status;
      error.reason = /^[A-Z_]{1,64}$/.test(reason || '') ? reason : undefined;
      throw error;
    }
    return result;
  }
  async lookup(body) {
    const user = (await this.request('lookup', body)).users?.[0];
    if (!user) { const error = new Error('Không tìm thấy tài khoản.'); error.code = 'auth/user-not-found'; throw error; }
    return userRecord(user);
  }
  getUser(uid) { return this.lookup({ localId: [uid] }); }
  getUserByEmail(email) { return this.lookup({ email: [email] }); }
  async createUser({ uid, ...data }) {
    const value = await this.request('', { localId: uid, ...data });
    return this.getUser(value.localId || uid);
  }
}

// Same business handlers as Functions: no client Admin SDK or relaxed rules.
export async function handleScheduling(request, env, { tokenProvider, verifyUser }) {
  const name = new URL(request.url).pathname.slice('/api/scheduling/'.length);
  let account;
  try { account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON || '{}'); }
  catch { return json({ error: { status: 'UNAVAILABLE', message: 'Cấu hình backend chưa sẵn sàng.' } }, 503); }
  if (account.project_id !== PROJECT || !env.FIREBASE_WEB_API_KEY) {
    return json({ error: { status: 'UNAVAILABLE', message: 'Backend chưa được kết nối đúng Firebase.' } }, 503);
  }
  if (request.method === 'GET' && name === 'health') {
    return json({ service: 'staff-scheduling', version: 1, projectId: PROJECT, transport: 'firestore-rest' });
  }
  if (!METHODS.has(name)) return json({ error: { status: 'NOT_FOUND', message: 'Chức năng không tồn tại.' } }, 404);
  if (request.method !== 'POST') return json({ error: { status: 'INVALID_ARGUMENT', message: 'Chỉ chấp nhận POST.' } }, 405);
  try {
    const identity = await verifyUser(request, env);
    if (!identity) return json({ error: { status: 'UNAUTHENTICATED', message: 'Vui lòng đăng nhập lại.' } }, 401);
    if (Number(request.headers.get('content-length')) > 65536) return json({ error: { message: 'Yêu cầu quá lớn.' } }, 413);
    const text = await request.text();
    if (new TextEncoder().encode(text).length > 65536) return json({ error: { message: 'Yêu cầu quá lớn.' } }, 413);
    let input;
    try { input = JSON.parse(text); } catch { return json({ error: { message: 'Dữ liệu không hợp lệ.' } }, 400); }
    if (!input?.data || typeof input.data !== 'object' || Array.isArray(input.data)) return json({ error: { message: 'Dữ liệu không hợp lệ.' } }, 400);
    const getToken = () => tokenProvider(env);
    const db = new RestFirestore({ projectId: PROJECT, tokenProvider: getToken,
      hints: name === 'saveRoster' || name === 'saveShifts' ? rosterHints(input.data) : {} });
    const auth = new RestAuth({ projectId: PROJECT, tokenProvider: getToken });
    const handlers = { ...staffModule.createStaffHandlers(db, auth), ...schedulingModule.createSchedulingHandlers(db, auth),
      ...reviewRatingModule.createReviewRatingHandlers(db, auth) };
    return json({ result: await handlers[name]({ auth: { uid: identity.userId }, data: input.data }) });
  } catch (error) {
    const status = STATUS[error.code];
    console.error(JSON.stringify({ event: 'scheduling.failure', method: name, code: error.code || 'internal',
      upstreamStatus: error.upstreamStatus, reason: error.reason, errorType: error.name,
      trace: error.stack?.split('\n').slice(1, 5).map((line) => line.trim()) }));
    return json({ error: { status: (error.code || 'unavailable').toUpperCase().replaceAll('-', '_'),
      message: status ? error.message : 'Chưa xác nhận được kết quả xử lý. Hãy thử lại cùng yêu cầu.' } }, status || 503);
  }
}
