'use strict';
const { requireWrites } = require('./write_control');
const { prepareLoyalty } = require('./loyalty');
const { employeeRatings } = require('./review_ratings');
const crypto = require('node:crypto');
const { HttpsError } = require('firebase-functions/v2/https');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const SALONS = {
  salon_01: { name: '30Shine 345 Nguyễn Văn Linh', opening: 420, closing: 1320 },
  salon_02: { name: '30Shine 130 Xô Viết Nghệ Tĩnh', opening: 420, closing: 1320 },
  salon_03: { name: '30Shine Sơn Trà (mô phỏng)', opening: 420, closing: 1320 },
};
const OFFSET = 7 * 3600000;
const DAY = 86400000;
const fail = (code, message) => { throw new HttpsError(code, message); };
function id(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) fail('invalid-argument', 'Mã định danh không hợp lệ.');
  return value;
}
function dateKey(ms) { return new Date(ms + OFFSET).toISOString().slice(0, 10); }
function dayStart(date) {
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) fail('invalid-argument', 'Ngày không hợp lệ.');
  const start = Date.parse(`${date}T00:00:00+07:00`);
  if (!Number.isFinite(start) || dateKey(start) !== date) fail('invalid-argument', 'Ngày không tồn tại.');
  return start;
}
function milliseconds(value) { return value?.toMillis?.() ?? null; }
function active(booking) { return !['cancelled', 'completed'].includes(booking.status); }
function duration(booking) {
  return booking.totalDurationMinutes ?? booking.services?.reduce((n, s) => n + Number(s.durationMinutes || 0), 0);
}
function interval(booking) {
  const start = milliseconds(booking.appointmentAt);
  const minutes = duration(booking);
  if (start === null || !Number.isSafeInteger(minutes) || minutes <= 0) {
    fail('failed-precondition', 'Có lịch hẹn cũ thiếu thời gian/thời lượng; cần đối chiếu trước khi đổi lịch làm.');
  }
  return [start, start + Math.ceil(minutes / 30) * 1800000];
}
function occupiedIntervals(booking) {
  const scheduled = interval(booking);
  if (booking.status !== 'in_service' || (booking.serviceStartedAt == null && booking.serviceExpectedEndAt == null)) return [scheduled];
  const start = milliseconds(booking.serviceStartedAt), end = milliseconds(booking.serviceExpectedEndAt);
  if (start === null || end === null || end <= start) fail('failed-precondition', 'Lịch đang phục vụ thiếu thời gian thực tế; cần đối chiếu trước khi đặt thêm.');
  // Preserve the booked reservation and the actual service window separately;
  // do not block a fictitious gap between an early service and the booked time.
  return [scheduled, [start, end]];
}
function overlaps(a, b) { return a[0] < b[1] && b[0] < a[1]; }
function shiftInterval(shift) {
  const start = dayStart(shift.dateKey);
  if (shift.status === 'off') return [start, start + DAY];
  return [start + shift.startMinute * 60000, start + shift.endMinute * 60000];
}
function available(shifts, bookings, salonId, start, minutes, excludeId) {
  const end = start + Math.ceil(minutes / 30) * 1800000;
  return shifts.some((s) => s.status === 'scheduled' && s.salonId === salonId &&
      shiftInterval(s)[0] <= start && shiftInterval(s)[1] >= end) &&
    !bookings.some((b) => b.id !== excludeId && active(b) && occupiedIntervals(b).some(window => overlaps([start, end], window)));
}

function createSchedulingHandlers(db, auth, { clock = () => Date.now() } = {}) {
  // Share employee/history reads only inside one transaction attempt, never
  // across requests/retries. Day guards and all-branch checks remain separate.
  const transactionEmployees = new WeakMap();
  async function identity(request, admin = false) {
    if (!request.auth) fail('unauthenticated', 'Vui lòng đăng nhập.');
    const user = await auth.getUser(request.auth.uid);
    if (user.disabled) fail('permission-denied', 'Tài khoản đã ngừng hoạt động.');
    if (admin && !(await db.doc(`admins/${user.uid}`).get()).exists) fail('permission-denied', 'Chỉ admin được quản lý ca.');
    return user;
  }
  async function adminCheck(tx, uid) {
    if (!(await tx.get(db.doc(`admins/${uid}`))).exists) fail('permission-denied', 'Quyền admin đã thay đổi.');
  }
  function validateShift(data) {
    id(data.employeeId);
    if (!SALONS[data.salonId]) fail('invalid-argument', 'Chi nhánh không hợp lệ.');
    dayStart(data.dateKey);
    if (data.dateKey < dateKey(clock())) fail('failed-precondition', 'Không sửa lịch làm của ngày đã qua.');
    const salon = SALONS[data.salonId];
    if (!Number.isInteger(data.startMinute) || !Number.isInteger(data.endMinute) ||
        data.startMinute % 30 || data.endMinute % 30 || data.startMinute < salon.opening ||
        data.endMinute > salon.closing || data.startMinute >= data.endMinute) {
      fail('invalid-argument', 'Ca phải trong giờ mở cửa, theo bước 30 phút và có giờ kết thúc sau giờ bắt đầu.');
    }
  }
  async function loadDay(tx, employeeId, date, cache) {
    const key = `${employeeId}_${date}`;
    if (cache.has(key)) return cache.get(key);
    const guard = db.doc(`employee_days/${key}`);
    let employeeReads = transactionEmployees.get(cache);
    if (!employeeReads) { employeeReads = new Map(); transactionEmployees.set(cache, employeeReads); }
    if (!employeeReads.has(employeeId)) employeeReads.set(employeeId, Promise.all([
      tx.get(db.doc(`employees/${employeeId}`)),
      // Legacy rows may lack dateKey/status/endAt. Keep the conservative scan
      // until a separately approved migration can bound these safely.
      tx.get(db.collection('bookings').where('barberId', '==', employeeId)),
    ]));
    const [employee, bookings] = await employeeReads.get(employeeId);
    const [guardDoc, shifts] = await Promise.all([
      tx.get(guard),
      tx.get(db.collection('work_shifts').where('employeeId', '==', employeeId).where('dateKey', '==', date)),
    ]);
    const profile = employee.data();
    const live = bookings.docs.map((doc) => ({ ...doc.data(), id: doc.id })).filter(active);
    // Validate legacy rows instead of silently excluding unknown occupied time.
    for (const booking of live) occupiedIntervals(booking);
    const result = {
      guard, version: guardDoc.data()?.version ?? 0, profile: profile ?? {},
      active: employee.exists && (!('isActive' in profile) || profile.isActive === true) && Boolean(SALONS[profile.salonId]),
      shifts: shifts.docs.map((doc) => ({ ...doc.data(), id: doc.id })).filter((s) => s.dateKey === date && ['scheduled', 'off'].includes(s.status)),
      bookings: live.filter((b) => {
        const start = dayStart(date);
        return occupiedIntervals(b).some(window => overlaps(window, [start, start + DAY]));
      }),
      inService: live.filter(b => b.status === 'in_service'),
    };
    cache.set(key, result);
    return result;
  }
  function guards(tx, cache) {
    for (const entry of cache.values()) tx.set(entry.guard, {
      version: entry.version + 1, updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  function audit(tx, action, uid, before, after) {
    tx.create(db.collection('audit_events').doc(), {
      action, actorUid: uid, before, after, createdAt: FieldValue.serverTimestamp(),
    });
  }
  function ensureSchedule(day, shifts) {
    for (let a = 0; a < shifts.length; a++) for (let b = a + 1; b < shifts.length; b++) {
      if (overlaps(shiftInterval(shifts[a]), shiftInterval(shifts[b]))) {
        const clockText = (minute) => `${String(Math.floor(minute / 60)).padStart(2, '0')}:${String(minute % 60).padStart(2, '0')}`;
        const describe = (shift) => {
          const hours = shift.status === 'off' ? 'OFF · nghỉ cả ngày 00:00–24:00' :
            `${shift.shiftCode || 'Ca làm'} · ${clockText(shift.startMinute)}–${clockText(shift.endMinute)}`;
          return `${hours} · ${SALONS[shift.salonId]?.name || shift.salonId}`;
        };
        const date = shifts[a].dateKey.split('-').reverse().join('/');
        fail('already-exists', `Xung đột lịch làm.\nNhân viên: ${day.profile.name || shifts[a].employeeId}\nNgày: ${date}\n• ${describe(shifts[a])}\n• ${describe(shifts[b])}\nCa làm không được trùng giờ hoặc nằm trong ngày OFF, kể cả khác chi nhánh. Các ca đã lưu được giữ nguyên.`);
      }
    }
    for (const booking of day.bookings) {
      if (!occupiedIntervals(booking).every(([start, end]) => available(shifts, [], booking.salonId, start, (end - start) / 60000))) {
        fail('failed-precondition', 'Thay đổi sẽ làm lịch hẹn còn hiệu lực nằm ngoài ca.');
      }
    }
  }
  // Monthly grid writes reuse the same employee/day guards as booking and A/B.
  // Replaced assignments are soft-cancelled, never deleted.
  async function saveRoster(request) {
    const user = await identity(request, true); const data = request.data ?? {};
    if (!SALONS[data.salonId] || !Array.isArray(data.cells) || !data.cells.length || data.cells.length > 100) {
      fail('invalid-argument', 'Chọn chi nhánh và từ 1 đến 100 ô.');
    }
    const shape = data.shift ?? {};
    if (!['work', 'off'].includes(shape.kind)) fail('invalid-argument', 'Chọn ca hoặc OFF.');
    const presets = { S: [420, 900], C: [840, 1320], F: [420, 1320], HC: [540, 1020] };
    if (shape.kind === 'work' && (!['S', 'C', 'F', 'HC', 'T'].includes(shape.code) ||
        (presets[shape.code] && (shape.startMinute !== presets[shape.code][0] || shape.endMinute !== presets[shape.code][1])))) {
      fail('invalid-argument', 'Mã ca không khớp giờ ca.');
    }
    const unique = new Set();
    for (const cell of data.cells) {
      if (!cell || typeof cell !== 'object' || Array.isArray(cell) ||
          Object.keys(cell).some((key) => !['employeeId', 'dateKey', 'expected'].includes(key))) {
        fail('invalid-argument', 'Ô phân ca không hợp lệ.');
      }
      id(cell.employeeId); dayStart(cell.dateKey);
      if (cell.dateKey < dateKey(clock())) fail('failed-precondition', 'Không sửa ngày đã qua.');
      const key = `${cell.employeeId}_${cell.dateKey}`;
      if (unique.has(key)) fail('invalid-argument', 'Không chọn trùng ô.'); unique.add(key);
      if (!Array.isArray(cell.expected) || cell.expected.length > 48 ||
          cell.expected.some((s) => !s || !Number.isSafeInteger(s.revision) || s.revision < 1) ||
          new Set(cell.expected.map((s) => s.id)).size !== cell.expected.length) fail('invalid-argument', 'Thiếu phiên bản phân công hợp lệ.');
      for (const row of cell.expected) id(row.id);
      if (shape.kind === 'work') validateShift({ ...shape, employeeId: cell.employeeId, dateKey: cell.dateKey, salonId: data.salonId });
    }
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'rosterWritesEnabled');
      await adminCheck(tx, user.uid);
      const op = await operation(tx, user.uid, data.requestId, data); if (op.result) return op.result;
      const cache = new Map(); const changes = [];
      for (const cell of data.cells) {
        const day = await loadDay(tx, cell.employeeId, cell.dateKey, cache);
        if (!day.active) fail('failed-precondition', 'Nhân viên không còn hoạt động.');
        const before = day.shifts.filter((s) => s.salonId === data.salonId);
        const versions = (rows) => rows.map((s) => `${s.id}:${s.revision}`).sort();
        if (JSON.stringify(versions(before)) !== JSON.stringify(versions(cell.expected))) fail('aborted', 'Lịch đã thay đổi sau bản xem trước. Hãy tải lại và chọn lại.');
        const next = { employeeId: cell.employeeId, dateKey: cell.dateKey, salonId: data.salonId,
          status: shape.kind === 'off' ? 'off' : 'scheduled', shiftCode: shape.kind === 'off' ? 'OFF' : shape.code,
          ...(shape.kind === 'work' ? { startMinute: shape.startMinute, endMinute: shape.endMinute } : {}),
          revision: 1, seriesId: data.requestId, supersedes: before.map((s) => s.id) };
        ensureSchedule(day, [...day.shifts.filter((s) => s.salonId !== data.salonId), next]);
        changes.push({ before, next, ref: db.collection('work_shifts').doc() });
      }
      if (changes.reduce((n, c) => n + c.before.length + 1, 0) + cache.size + 2 > 450) fail('invalid-argument', 'Quá nhiều ca trong một lần lưu; hãy chia nhỏ lựa chọn.');
      const stamp = FieldValue.serverTimestamp();
      for (const change of changes) {
        for (const old of change.before) tx.update(db.doc(`work_shifts/${old.id}`), {
          status: 'cancelled', revision: old.revision + 1, updatedAt: stamp, updatedBy: user.uid, replacedBy: change.ref.id,
        });
        tx.create(change.ref, { ...change.next, createdAt: stamp, updatedAt: stamp, updatedBy: user.uid });
      }
      guards(tx, cache);
      audit(tx, 'roster.assign', user.uid, changes.flatMap((c) => c.before), changes.map((c) => ({ id: c.ref.id, ...c.next })));
      return finishOperation(tx, op, { shiftIds: changes.map((c) => c.ref.id) });
    });
  }
  async function operation(tx, uid, requestId, payload) {
    const owner = crypto.createHash('sha256').update(uid).digest('hex');
    const ref = db.doc(`schedule_operations/${owner}_${id(requestId)}`);
    const fingerprint = crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex');
    const saved = await tx.get(ref);
    if (saved.exists && saved.data().fingerprint !== fingerprint) fail('already-exists', 'Mã yêu cầu đã được dùng cho thao tác khác.');
    return { ref, fingerprint, result: saved.data()?.result };
  }
  function finishOperation(tx, op, result) {
    tx.create(op.ref, { fingerprint: op.fingerprint, result, createdAt: FieldValue.serverTimestamp() });
    return result;
  }

  async function saveShifts(request) {
    const user = await identity(request, true); const data = request.data ?? {};
    const dates = data.dates;
    if (!Array.isArray(dates) || dates.length < 1 || dates.length > 31 || new Set(dates).size !== dates.length) fail('invalid-argument', 'Chọn từ 1 đến 31 ngày, không trùng.');
    for (const date of dates) validateShift({ ...data, dateKey: date });
    if (data.shiftId && (dates.length !== 1 || !Number.isInteger(data.expectedRevision))) fail('invalid-argument', 'Sửa một ca cần phiên bản hiện tại.');
    const shiftRefs = dates.map(() => db.collection('work_shifts').doc());
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'rosterWritesEnabled');
      await adminCheck(tx, user.uid);
      const op = await operation(tx, user.uid, data.requestId, data);
      if (op.result) return op.result;
      const cache = new Map(); const writes = [];
      let old;
      if (data.shiftId) {
        const snap = await tx.get(db.doc(`work_shifts/${id(data.shiftId)}`));
        if (!snap.exists) fail('not-found', 'Không tìm thấy ca.');
        old = { ...snap.data(), id: snap.id };
        if (old.revision !== data.expectedRevision || old.status !== 'scheduled') fail('aborted', 'Ca đã thay đổi; hãy tải lại.');
        if (old.dateKey < dateKey(clock())) fail('failed-precondition', 'Không sửa ca của ngày đã qua.');
        await loadDay(tx, old.employeeId, old.dateKey, cache);
      }
      for (let index = 0; index < dates.length; index++) {
        const date = dates[index];
        const day = await loadDay(tx, data.employeeId, date, cache);
        if (!day.active) fail('failed-precondition', 'Nhân viên không còn hoạt động.');
        const next = { employeeId: data.employeeId, salonId: data.salonId, dateKey: date,
          startMinute: data.startMinute, endMinute: data.endMinute, status: 'scheduled',
          shiftCode: Object.entries({ S: [420, 900], C: [840, 1320], F: [420, 1320], HC: [540, 1020] }).find(([, hours]) => hours[0] === data.startMinute && hours[1] === data.endMinute)?.[0] ?? 'T',
          revision: (old?.revision ?? 0) + 1, seriesId: old?.seriesId ?? data.requestId };
        writes.push({ ref: old ? db.doc(`work_shifts/${old.id}`) : shiftRefs[index], next });
      }
      for (const [key, day] of cache) {
        const proposed = day.shifts.filter((s) => s.id !== old?.id);
        for (const { next, ref } of writes) if (key === `${next.employeeId}_${next.dateKey}`) proposed.push({ ...next, id: ref.id });
        ensureSchedule(day, proposed);
      }
      const stamp = FieldValue.serverTimestamp();
      for (const { ref, next } of writes) {
        if (old) tx.update(ref, { ...next, updatedAt: stamp, updatedBy: user.uid });
        else tx.create(ref, { ...next, createdAt: stamp, updatedAt: stamp, updatedBy: user.uid });
      }
      guards(tx, cache); audit(tx, old ? 'shift.update' : 'shift.create', user.uid, old ?? null, writes.map((w) => ({ id: w.ref.id, ...w.next })));
      return finishOperation(tx, op, { shiftIds: writes.map((w) => w.ref.id) });
    });
  }
  async function cancelShift(request) {
    const user = await identity(request, true); const data = request.data ?? {};
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'rosterWritesEnabled');
      await adminCheck(tx, user.uid);
      const op = await operation(tx, user.uid, data.requestId, data); if (op.result) return op.result;
      const ref = db.doc(`work_shifts/${id(data.shiftId)}`); const snap = await tx.get(ref);
      if (!snap.exists) fail('not-found', 'Không tìm thấy ca.');
      const old = { ...snap.data(), id: snap.id };
      if (old.revision !== data.expectedRevision || !['scheduled', 'off'].includes(old.status)) fail('aborted', 'Ca đã thay đổi; hãy tải lại.');
      if (old.dateKey < dateKey(clock())) fail('failed-precondition', 'Không hủy ca của ngày đã qua.');
      const cache = new Map(); const day = await loadDay(tx, old.employeeId, old.dateKey, cache);
      ensureSchedule(day, day.shifts.filter((s) => s.id !== old.id));
      const update = { status: 'cancelled', revision: old.revision + 1, updatedAt: FieldValue.serverTimestamp(), updatedBy: user.uid };
      tx.update(ref, update); guards(tx, cache); audit(tx, 'shift.cancel', user.uid, old, { ...old, status: 'cancelled' });
      return finishOperation(tx, op, { shiftId: ref.id });
    });
  }
  async function swapShifts(request) {
    const user = await identity(request, true); const data = request.data ?? {};
    if (data.shiftAId === data.shiftBId) fail('invalid-argument', 'Chọn hai ca khác nhau.');
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'rosterWritesEnabled');
      await adminCheck(tx, user.uid);
      const op = await operation(tx, user.uid, data.requestId, data); if (op.result) return op.result;
      const refs = [data.shiftAId, data.shiftBId].map((value) => db.doc(`work_shifts/${id(value)}`));
      const snapshots = await tx.getAll(...refs);
      if (snapshots.some((s) => !s.exists)) fail('not-found', 'Ca không còn tồn tại.');
      const [a, b] = snapshots.map((s) => ({ ...s.data(), id: s.id }));
      if (a.status !== 'scheduled' || b.status !== 'scheduled' || a.revision !== data.revisionA || b.revision !== data.revisionB) fail('aborted', 'Ca đã thay đổi; hãy tải lại.');
      if (a.employeeId === b.employeeId) fail('invalid-argument', 'Đổi A/B cần hai nhân viên khác nhau; hai ca có thể cùng ngày.');
      if ([a.dateKey, b.dateKey].some((date) => date < dateKey(clock()))) fail('failed-precondition', 'Không đổi ca của ngày đã qua.');
      const cache = new Map();
      for (const employee of [a.employeeId, b.employeeId]) for (const date of new Set([a.dateKey, b.dateKey])) {
        const day = await loadDay(tx, employee, date, cache);
        if (!day.active) fail('failed-precondition', 'Nhân viên không còn hoạt động.');
        if (day.bookings.length) fail('failed-precondition', 'Cả hai nhân viên phải không có lịch hẹn còn hiệu lực trong các ngày được chọn, tại mọi chi nhánh.');
      }
      const nextA = { ...a, employeeId: b.employeeId, revision: a.revision + 1 };
      const nextB = { ...b, employeeId: a.employeeId, revision: b.revision + 1 };
      for (const [key, day] of cache) {
        const shifts = day.shifts.filter((s) => s.id !== a.id && s.id !== b.id);
        for (const s of [nextA, nextB]) if (key === `${s.employeeId}_${s.dateKey}`) shifts.push(s);
        ensureSchedule(day, shifts);
      }
      for (const [index, next] of [nextA, nextB].entries()) tx.update(refs[index], {
        employeeId: next.employeeId, revision: next.revision, updatedBy: user.uid, updatedAt: FieldValue.serverTimestamp(),
      });
      guards(tx, cache); audit(tx, 'shift.swap', user.uid, [a, b], [nextA, nextB]);
      return finishOperation(tx, op, { shiftIds: refs.map((r) => r.id) });
    });
  }

  async function catalog(tx, serviceIds) {
    if (!Array.isArray(serviceIds) || !serviceIds.length || serviceIds.length > 10 || new Set(serviceIds).size !== serviceIds.length) fail('invalid-argument', 'Chọn 1–10 dịch vụ khác nhau.');
    const rows = await tx.getAll(...serviceIds.map((value) => db.doc(`services/${id(value)}`)));
    const services = rows.map((row) => {
      const value = row.data();
      if (!row.exists || value.isActive === false || !Number.isSafeInteger(value.price) || value.price < 0 ||
          !Number.isSafeInteger(value.durationMinutes) || value.durationMinutes <= 0 || typeof value.name !== 'string' ||
          !value.name.length || value.name.length > 100) fail('failed-precondition', 'Dịch vụ không còn hợp lệ; hãy chọn lại.');
      return { id: row.id, name: value.name, price: value.price, durationMinutes: value.durationMinutes };
    });
    const price = services.reduce((n, s) => n + s.price, 0);
    const minutes = services.reduce((n, s) => n + s.durationMinutes, 0);
    if (!Number.isSafeInteger(price) || !Number.isSafeInteger(minutes) || price <= 0 || minutes > 900) fail('invalid-argument', 'Tổng giá/thời lượng dịch vụ không hợp lệ.');
    return { services, price, minutes };
  }
  function bookingTime(data) {
    const start = data.appointmentAt;
    if (!SALONS[data.salonId] || !Number.isSafeInteger(start) || start <= clock()) fail('invalid-argument', 'Chi nhánh hoặc thời gian đặt lịch không hợp lệ.');
    const date = dateKey(start); const minute = (start - dayStart(date)) / 60000;
    if (minute % 30 !== 0) fail('invalid-argument', 'Giờ đặt lịch phải theo bước 30 phút.');
    return { start, date, minute };
  }
  async function vouchers(tx, selected, uid, price) {
    if (!Array.isArray(selected) || selected.length > 2) fail('invalid-argument', 'Danh sách voucher không hợp lệ.');
    if (selected.length > 1 && selected.some((v) => v.isPersonal !== true)) fail('invalid-argument', 'Không dùng chung mã khuyến mãi với voucher tích lũy.');
    const seen = new Set(); const rewards = new Set(); const changes = []; const applied = []; let discount = 0;
    for (const item of selected) {
      if (!item || typeof item !== 'object' || typeof item.isPersonal !== 'boolean') fail('invalid-argument', 'Voucher không hợp lệ.');
      const key = id(item.id); const personal = item.isPersonal === true;
      if (seen.has(key)) fail('invalid-argument', 'Voucher bị trùng.'); seen.add(key);
      const ref = db.doc(personal ? `users/${uid}/vouchers/${key}` : `voucher_templates/${key}`);
      const snap = await tx.get(ref); const value = snap.data();
      const redemption = personal ? null : db.doc(`voucher_templates/${key}/redemptions/${uid}`);
      const redeemed = redemption ? await tx.get(redemption) : null;
      if (!snap.exists || value.isActive !== true || (personal && value.isUsed !== false) || redeemed?.exists ||
          !Number.isInteger(value.discountPercent) || value.discountPercent <= 0 || value.discountPercent > 100 ||
          price < (value.minOrderAmount ?? 0) || (value.expiresAt && milliseconds(value.expiresAt) <= clock()) ||
          (!personal && value.usageLimit > 0 && (value.usedCount ?? 0) >= value.usageLimit)) fail('failed-precondition', 'Voucher không còn đủ điều kiện.');
      const code = value.code ?? ''; const source = value.source ?? 'admin';
      const reward = value.rewardType === 'minimum_order' || key.startsWith('loyalty_order_') || source === 'loyalty_order' ||
          code.toUpperCase().startsWith('DON') || code.toUpperCase() === 'CHITIEU' ? 'minimum_order' : 'visit_count';
      if (personal && rewards.has(reward)) fail('invalid-argument', 'Chỉ chọn một voucher mỗi loại tích lũy.');
      rewards.add(reward); discount += Math.floor(price * value.discountPercent / 100);
      changes.push({ ref, redemption, personal, usedCount: value.usedCount ?? 0 });
      applied.push({ id: key, code: reward === 'minimum_order' ? 'CHITIEU' : code, title: value.title ?? '',
        discountPercent: value.discountPercent, minOrderAmount: value.minOrderAmount ?? 0,
        usageLimit: value.usageLimit ?? 0, source, isPersonal: personal, rewardType: reward });
    }
    if (discount >= price) fail('failed-precondition', 'Tổng thanh toán phải lớn hơn 0.');
    return { discount, applied, changes };
  }
  function applyVouchers(tx, values, bookingId, uid) {
    for (const v of values.changes) {
      if (v.personal) tx.update(v.ref, { isUsed: true, usedBookingId: bookingId, usedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      else {
        tx.update(v.ref, { usedCount: v.usedCount + 1, lastBookingId: bookingId, updatedAt: FieldValue.serverTimestamp() });
        tx.create(v.redemption, { userId: uid, bookingId, usedAt: FieldValue.serverTimestamp() });
      }
    }
  }
  function slotRows(bookingId, booking) {
    const start = milliseconds(booking.appointmentAt);
    return Array.from({ length: Math.ceil(booking.totalDurationMinutes / 30) }, (_, index) => {
      const time = start + index * 1800000;
      return { id: `${bookingId}_${time}`, bookingId, userId: booking.userId, salonId: booking.salonId,
        barberId: booking.barberId, slotAt: Timestamp.fromMillis(time), state: 'active' };
    });
  }
  function writeSlots(tx, bookingId, booking, oldSlots = []) {
    const next = slotRows(bookingId, booking); const ids = new Set(next.map((s) => s.id));
    for (const old of oldSlots) if (!ids.has(old.id)) tx.update(old.ref, { state: 'released', releasedAt: FieldValue.serverTimestamp() });
    for (const row of next) {
      const { id: key, ...data } = row;
      const old = oldSlots.find((s) => s.id === key);
      if (!old) tx.create(db.doc(`booking_slots/${key}`), { ...data, createdAt: FieldValue.serverTimestamp() });
      else tx.update(old.ref, { state: 'active', updatedAt: FieldValue.serverTimestamp() });
    }
    return next.map((s) => s.id);
  }
  async function createBooking(request) {
    const user = await identity(request); const data = request.data ?? {};
    const { start, date } = bookingTime(data);
    if (!['pay_now', 'pay_later'].includes(data.paymentChoice) || !/^0\d{9}$/.test(data.userPhone ?? '')) fail('invalid-argument', 'Thông tin thanh toán/số điện thoại không hợp lệ.');
    const ref = db.collection('bookings').doc();
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'bookingWritesEnabled');
      const op = await operation(tx, user.uid, data.requestId, data); if (op.result) return op.result;
      const profile = await tx.get(db.doc(`users/${user.uid}`));
      if (!profile.exists || (profile.data().requiresEmailVerification === true && !user.emailVerified)) fail('permission-denied', 'Cần hồ sơ hợp lệ và xác minh email.');
      const items = await catalog(tx, data.serviceIds);
      if ((data.expectedPrice !== undefined && data.expectedPrice !== items.price) ||
          (data.expectedDuration !== undefined && data.expectedDuration !== items.minutes)) {
        fail('failed-precondition', 'Giá hoặc thời lượng dịch vụ đã thay đổi. Vui lòng chọn lại dịch vụ.');
      }
      const values = await vouchers(tx, data.vouchers ?? [], user.uid, items.price);
      const shiftQuery = await tx.get(db.collection('work_shifts').where('salonId', '==', data.salonId).where('dateKey', '==', date));
      const candidates = [...new Set(shiftQuery.docs.map((s) => s.data()).filter((s) => s.dateKey === date && s.status === 'scheduled').map((s) => s.employeeId))];
      const requested = data.barberId ? id(data.barberId) : null;
      const cache = new Map(); let assigned;
      for (const employeeId of candidates.filter((e) => !requested || e === requested).sort()) {
        const day = await loadDay(tx, employeeId, date, cache);
        if (day.active && available(day.shifts, day.bookings, data.salonId, start, items.minutes)) { assigned = { employeeId, day }; break; }
      }
      if (!assigned) fail('failed-precondition', 'Không có nhân viên có ca phù hợp và đủ giờ trống.');
      const hairstyle = data.hairstyleId ? await tx.get(db.doc(`hairstyles/${id(data.hairstyleId)}`)) : null;
      if (hairstyle && (!hairstyle.exists || hairstyle.data().isActive === false)) fail('failed-precondition', 'Mẫu tóc không còn khả dụng.');
      const stamp = FieldValue.serverTimestamp();
      const bookedShift = assigned.day.shifts.find((s) => s.salonId === data.salonId &&
        shiftInterval(s)[0] <= start && shiftInterval(s)[1] >= start + Math.ceil(items.minutes / 30) * 1800000);
      const booking = { schemaVersion: 2, userId: user.uid, userName: profile.data().name ?? user.displayName ?? '',
        userEmail: user.email ?? '', userPhone: data.userPhone, salonId: data.salonId, salonName: SALONS[data.salonId].name,
        barberId: assigned.employeeId, barberName: assigned.day.profile.name ?? '', useAnyBarber: !requested,
        workShiftId: bookedShift.id, shiftRevision: bookedShift.revision,
        autoAssignedBarber: !requested, appointmentAt: Timestamp.fromMillis(start),
        selectedTime: new Date(start + OFFSET).toISOString().slice(11, 16),
        serviceIds: data.serviceIds, services: items.services, totalDurationMinutes: items.minutes,
        originalPrice: items.price, discountAmount: values.discount, totalPrice: items.price - values.discount,
        voucherIds: values.applied.map((v) => v.id), vouchers: values.applied, voucher: values.applied[0] ?? null,
        hairstyle: hairstyle ? { id: hairstyle.id, ...hairstyle.data() } : null,
        status: data.paymentChoice === 'pay_later' ? 'confirmed' : 'pending',
        payment: { provider: 'vnpay', environment: 'sandbox', choice: data.paymentChoice, status: 'unpaid', amount: items.price - values.discount },
        createdAt: stamp, updatedAt: stamp };
      booking.slotIds = slotRows(ref.id, booking).map((s) => s.id);
      tx.create(ref, booking); writeSlots(tx, ref.id, booking); applyVouchers(tx, values, ref.id, user.uid);
      guards(tx, cache); audit(tx, 'booking.create', user.uid, null, { bookingId: ref.id, barberId: booking.barberId, dateKey: date });
      return finishOperation(tx, op, { bookingId: ref.id });
    });
  }
  async function updateBookingServices(request) {
    const user = await identity(request); const data = request.data ?? {};
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'bookingWritesEnabled');
      const op = await operation(tx, user.uid, data.requestId, data); if (op.result) return op.result;
      const ref = db.doc(`bookings/${id(data.bookingId)}`); const snap = await tx.get(ref);
      if (!snap.exists) fail('not-found', 'Không tìm thấy lịch hẹn.');
      const old = snap.data();
      if (old.userId !== user.uid) fail('permission-denied', 'Không được sửa lịch của người khác.');
      if (!['pending', 'confirmed'].includes(old.status) || old.payment?.status !== 'unpaid' || (old.voucherIds ?? []).length) fail('failed-precondition', 'Lịch hẹn không còn được đổi dịch vụ.');
      const start = milliseconds(old.appointmentAt); if (start === null || start <= clock()) fail('failed-precondition', 'Lịch hẹn đã đến giờ.');
      const cache = new Map(); const day = await loadDay(tx, old.barberId, dateKey(start), cache);
      const items = await catalog(tx, data.serviceIds);
      const slots = await tx.get(db.collection('booking_slots').where('bookingId', '==', ref.id));
      if (!day.active || !available(day.shifts, day.bookings, old.salonId, start, items.minutes, ref.id)) fail('failed-precondition', 'Ca làm hoặc giờ trống không đủ cho dịch vụ mới.');
      const next = { ...old, services: items.services, serviceIds: data.serviceIds, totalDurationMinutes: items.minutes,
        originalPrice: items.price, totalPrice: items.price, discountAmount: 0, payment: { ...old.payment, amount: items.price } };
      const slotIds = writeSlots(tx, ref.id, next, slots.docs);
      tx.update(ref, { services: next.services, serviceIds: next.serviceIds, totalDurationMinutes: next.totalDurationMinutes,
        originalPrice: next.originalPrice, totalPrice: next.totalPrice, discountAmount: 0, payment: next.payment,
        slotIds, updatedAt: FieldValue.serverTimestamp() });
      guards(tx, cache); audit(tx, 'booking.services', user.uid, old, next);
      return finishOperation(tx, op, { bookingId: ref.id });
    });
  }
  async function changeBookingStatus(request) {
    const user = await identity(request); const data = request.data ?? {};
    if (!['pending', 'confirmed', 'in_service', 'cancelled', 'completed'].includes(data.status)) fail('invalid-argument', 'Trạng thái không hợp lệ.');
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'bookingWritesEnabled');
      const op = await operation(tx, user.uid, data.requestId, data); if (op.result) return op.result;
      const ref = db.doc(`bookings/${id(data.bookingId)}`); const snap = await tx.get(ref);
      const admin = await tx.get(db.doc(`admins/${user.uid}`));
      if (!snap.exists) fail('not-found', 'Không tìm thấy lịch hẹn.');
      const old = snap.data();
      const staffAction = !admin.exists && ['in_service', 'completed'].includes(data.status);
      if (staffAction) {
        const account = await tx.get(db.doc(`staff_accounts/${user.uid}`));
        if (!user.emailVerified || account.data()?.active !== true || account.data()?.employeeId !== old.barberId) {
          fail('permission-denied', 'Chỉ nhân viên đang hoạt động được giao lịch này mới được phục vụ.');
        }
        const [employee, link] = await tx.getAll(db.doc(`employees/${old.barberId}`), db.doc(`employee_accounts/${old.barberId}`));
        if (!employee.exists || ('isActive' in employee.data() && employee.data().isActive !== true) || !SALONS[employee.data().salonId] || link.data()?.uid !== user.uid) {
          fail('permission-denied', 'Hồ sơ nhân viên hoặc liên kết tài khoản không còn hợp lệ.');
        }
      } else if (!admin.exists && (old.userId !== user.uid || data.status !== 'cancelled')) {
        fail('permission-denied', 'Không được đổi trạng thái lịch này.');
      }
      if (old.status === data.status) return finishOperation(tx, op, { bookingId: ref.id });
      if (['completed', 'cancelled'].includes(old.status)) fail('failed-precondition', 'Không khôi phục lịch đã kết thúc.');
      if (!admin.exists && !staffAction && !(old.status === 'pending' || (old.status === 'confirmed' && old.payment?.choice === 'pay_later' && old.payment?.status === 'unpaid'))) fail('failed-precondition', 'Lịch không còn được hủy.');
      const effectiveStatus = old.status === 'pending' && (old.payment?.choice === 'pay_later' || old.payment?.status === 'paid') ? 'confirmed' : old.status;
      if (data.status === 'in_service' && effectiveStatus !== 'confirmed') fail('failed-precondition', 'Lịch phải được xác nhận trước khi bắt đầu.');
      if (data.status === 'completed' && !(staffAction ? old.status === 'in_service' : ['confirmed', 'in_service'].includes(effectiveStatus))) fail('failed-precondition', 'Cần bắt đầu phục vụ trước khi hoàn thành lịch.');
      const start = milliseconds(old.appointmentAt); if (start === null) fail('failed-precondition', 'Lịch cũ thiếu thời gian.');
      const serviceNow = clock();
      if (data.status === 'in_service' && dateKey(start) !== dateKey(serviceNow)) {
        fail('failed-precondition', 'Chỉ bắt đầu phục vụ lịch hẹn trong ngày hôm nay.');
      }
      const cache = new Map(); const day = await loadDay(tx, old.barberId, dateKey(start), cache);
      if (staffAction && !day.active) fail('permission-denied', 'Nhân viên đã ngừng hoạt động.');
      if (data.status === 'in_service' && day.inService.some(b => b.id !== ref.id)) {
        fail('failed-precondition', 'Hãy hoàn thành lịch đang phục vụ trước khi bắt đầu lịch khác.');
      }
      if (data.status === 'in_service' && (!day.active || !available(day.shifts, day.bookings, old.salonId, serviceNow, duration(old), ref.id))) {
        fail('failed-precondition', 'Chưa thể bắt đầu lúc này: cần đang trong ca và đủ thời gian phục vụ, không trùng lịch hẹn còn hiệu lực khác.');
      }
      const slots = await tx.get(db.collection('booking_slots').where('bookingId', '==', ref.id));
      if (['pending', 'confirmed'].includes(data.status) && (!day.active || !available(day.shifts, day.bookings, old.salonId, start, duration(old), ref.id))) fail('failed-precondition', 'Không còn ca/giờ trống phù hợp.');
      const award = data.status === 'completed' ? await prepareLoyalty(tx, db, ref.id, old) : () => {};
      // Completing a pay-at-salon appointment also confirms full payment.
      // Keep this in the same transaction as completion so retries cannot
      // produce a completed/unpaid row or a second receipt.
      let completionPayment = {};
      if (data.status === 'completed' && old.payment?.status !== 'paid') {
        if (old.payment?.choice !== 'pay_later' || old.payment?.status !== 'unpaid' || old.payment?.receipt ||
            !Number.isSafeInteger(old.totalPrice) || old.totalPrice < 0) {
          fail('failed-precondition', 'Chưa thể hoàn thành: cần đối chiếu số tiền hoặc kết quả thanh toán online.');
        }
        const stamp = FieldValue.serverTimestamp(), receiptId = `salon_${ref.id}`;
        const receipt = { id: receiptId, amount: old.totalPrice, method: 'completion',
          recordedBy: user.uid, recordedAt: stamp, employeeId: old.barberId,
          salonId: old.salonId, source: 'booking_completion' };
        completionPayment = { 'payment.status': 'paid', 'payment.provider': 'salon',
          'payment.environment': 'manual', 'payment.amount': old.totalPrice,
          'payment.method': 'completion', 'payment.paidAt': stamp,
          'payment.paidBy': user.uid, 'payment.receipt': receipt };
        audit(tx, 'booking.payment.record', user.uid,
          { bookingId: ref.id, paymentStatus: old.payment.status },
          { bookingId: ref.id, receiptId, amount: old.totalPrice, method: 'completion', source: 'booking_completion' });
        tx.create(db.doc(`users/${old.userId}/notifications/${receiptId}`), {
          type: 'payment_recorded', title: 'Đã ghi nhận thanh toán tại salon',
          message: `Lịch hẹn đã hoàn thành và được ghi nhận thanh toán ${old.totalPrice.toLocaleString('vi-VN')}đ.`,
          bookingId: ref.id, receiptId, createdAt: stamp,
        });
      }
      tx.update(ref, { status: data.status, updatedAt: FieldValue.serverTimestamp(),
        ...completionPayment,
        ...(data.status === 'in_service' ? { startedAt: FieldValue.serverTimestamp(), startedBy: user.uid,
          serviceStartedAt: Timestamp.fromMillis(serviceNow), serviceExpectedEndAt: Timestamp.fromMillis(serviceNow + Math.ceil(duration(old) / 30) * 1800000),
          startedEarly: serviceNow < start } : {}),
        ...(data.status === 'completed' ? { completedAt: FieldValue.serverTimestamp(), completedBy: user.uid } : {}),
        ...(data.status === 'cancelled' && old.payment?.status === 'paid' ? { 'payment.refundRequired': true } : {}) });
      award();
      if (['cancelled', 'completed'].includes(data.status)) for (const slot of slots.docs) tx.update(slot.ref, { state: 'released', releasedAt: FieldValue.serverTimestamp() });
      guards(tx, cache); audit(tx, 'booking.status', user.uid, { bookingId: ref.id, status: old.status }, { status: data.status,
        ...(data.status === 'in_service' ? { startedEarly: serviceNow < start, serviceStartedAt: Timestamp.fromMillis(serviceNow) } : {}) });
      tx.create(db.doc(`users/${old.userId}/notifications/schedule_${id(data.requestId)}`), {
        type: `booking_${data.status}`, title: 'Lịch hẹn đã được cập nhật',
        message: `Trạng thái lịch hẹn tại ${old.salonName ?? ''}: ${data.status}.`, bookingId: ref.id,
        salonId: old.salonId, createdAt: FieldValue.serverTimestamp(),
      });
      return finishOperation(tx, op, { bookingId: ref.id });
    });
  }
  async function recordBookingPayment(request) {
    const user = await identity(request, true); const data = request.data ?? {};
    const bookingId = id(data.bookingId);
    if (!['cash', 'bank_transfer'].includes(data.method)) fail('invalid-argument', 'Chọn tiền mặt hoặc chuyển khoản.');
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'bookingWritesEnabled');
      await adminCheck(tx, user.uid);
      const op = await operation(tx, user.uid, data.requestId, data); if (op.result) return op.result;
      const ref = db.doc(`bookings/${bookingId}`); const snap = await tx.get(ref);
      if (!snap.exists) fail('not-found', 'Không tìm thấy lịch hẹn.');
      const booking = snap.data(); const amount = booking.totalPrice;
      if (booking.status !== 'completed') fail('failed-precondition', 'Chỉ ghi nhận thu tiền cho lịch đã hoàn thành.');
      if (!Number.isSafeInteger(amount) || amount <= 0 || data.expectedAmount !== amount) {
        fail('failed-precondition', 'Số tiền không hợp lệ hoặc đã thay đổi. Tải lại lịch trước khi ghi nhận.');
      }
      // The booking itself is the per-booking guard: different requests/admins
      // racing to collect can create only one immutable receipt, even on retry.
      if (booking.payment?.status === 'paid') return finishOperation(tx, op, {
        bookingId, amount, alreadyPaid: true, receiptId: booking.payment.receipt?.id ?? null,
      });
      if (booking.payment?.choice !== 'pay_later' || booking.payment?.status !== 'unpaid' || booking.payment?.receipt) {
        fail('failed-precondition', 'Chỉ ghi nhận lịch thanh toán tại quầy chưa thu tiền; không thay kết quả VNPAY.');
      }
      const stamp = FieldValue.serverTimestamp();
      const receiptId = `salon_${bookingId}`;
      const receipt = { id: receiptId, amount, method: data.method, recordedBy: user.uid,
        recordedAt: stamp, employeeId: booking.barberId, salonId: booking.salonId };
      tx.update(ref, { 'payment.status': 'paid', 'payment.provider': 'salon', 'payment.environment': 'manual',
        'payment.amount': amount, 'payment.method': data.method, 'payment.paidAt': stamp,
        'payment.paidBy': user.uid, 'payment.receipt': receipt, updatedAt: stamp });
      audit(tx, 'booking.payment.record', user.uid, { bookingId, paymentStatus: booking.payment.status },
        { bookingId, receiptId, amount, method: data.method });
      tx.create(db.doc(`users/${booking.userId}/notifications/${receiptId}`), {
        type: 'payment_recorded', title: 'Đã ghi nhận thanh toán tại salon',
        message: `Salon đã ghi nhận ${amount.toLocaleString('vi-VN')}đ cho lịch hẹn của bạn.`,
        bookingId, receiptId, createdAt: stamp,
      });
      return finishOperation(tx, op, { bookingId, receiptId, amount, alreadyPaid: false });
    });
  }
  async function getAvailability(request) {
    await identity(request); const data = request.data ?? {};
    if (!SALONS[data.salonId]) fail('invalid-argument', 'Chi nhánh không hợp lệ.');
    dayStart(data.dateKey);
    return db.runTransaction(async (tx) => {
      const items = await catalog(tx, data.serviceIds);
      const all = await tx.get(db.collection('work_shifts').where('salonId', '==', data.salonId).where('dateKey', '==', data.dateKey));
      const employees = [...new Set(all.docs.map((doc) => doc.data()).filter((s) => s.dateKey === data.dateKey && s.status === 'scheduled').map((s) => s.employeeId))];
      const cache = new Map(); const days = [];
      for (const employee of employees) {
        const snapshot = await tx.get(db.doc(`employees/${employee}`));
        if (!snapshot.exists || snapshot.data().isActive === false) continue;
        const day = await loadDay(tx, employee, data.dateKey, cache);
        if (day.active) days.push({ employeeId: employee, day });
      }
      const slots = [];
      for (let minute = SALONS[data.salonId].opening; minute < SALONS[data.salonId].closing; minute += 30) {
        const start = dayStart(data.dateKey) + minute * 60000;
        const ids = start > clock() ? days.filter(({ employeeId, day }) => (!data.barberId || data.barberId === employeeId) &&
          available(day.shifts, day.bookings, data.salonId, start, items.minutes)).map((row) => row.employeeId) : [];
        if (ids.length) slots.push({ time: `${String(Math.floor(minute / 60)).padStart(2, '0')}:${String(minute % 60).padStart(2, '0')}`, employeeIds: ids });
      }
      return { slots, durationMinutes: items.minutes, price: items.price };
    });
  }
  async function listBookableStaff(request) {
    await identity(request); const data = request.data ?? {};
    if (!SALONS[data.salonId]) fail('invalid-argument', 'Chi nhánh không hợp lệ.');
    const today = dateKey(clock()); const end = dateKey(clock() + 7 * DAY);
    const shifts = await db.collection('work_shifts').where('salonId', '==', data.salonId)
      .where('dateKey', '>=', today).where('dateKey', '<', end).get();
    const ids = [...new Set(shifts.docs.map((s) => s.data()).filter((s) => s.status === 'scheduled' && s.dateKey >= today && s.dateKey < end).map((s) => s.employeeId))];
    const profiles = ids.length ? await db.getAll(...ids.map((value) => db.doc(`employees/${value}`))) : [];
    const activeProfiles = profiles.filter((s) => s.exists && s.data().isActive !== false);
    const ratings = new Map((await employeeRatings(db, activeProfiles.map(s => s.id))).map(r => [r.employeeId, r]));
    return { employees: activeProfiles.map(s => ({ ...s.data(), ...ratings.get(s.id), id: s.id })) };
  }
  async function releaseStaleSlots(request) {
    const user = await identity(request, true); const salonId = request.data?.salonId;
    if (!SALONS[salonId]) fail('invalid-argument', 'Chi nhánh không hợp lệ.');
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'rosterWritesEnabled');
      await adminCheck(tx, user.uid);
      const slots = await tx.get(db.collection('booking_slots').where('salonId', '==', salonId));
      const release = [];
      for (const slot of slots.docs.filter((s) => s.data().state !== 'released')) {
        const booking = await tx.get(db.doc(`bookings/${id(slot.data().bookingId)}`));
        if (booking.exists && !active(booking.data())) release.push(slot);
      }
      for (const slot of release) tx.update(slot.ref, { state: 'released', releasedAt: FieldValue.serverTimestamp() });
      if (release.length) audit(tx, 'slots.release', user.uid, release.map((s) => ({ id: s.id, ...s.data() })), { count: release.length });
      return { count: release.length };
    });
  }
  return { saveRoster, saveShifts, cancelShift, swapShifts, createBooking, updateBookingServices, changeBookingStatus, recordBookingPayment, getAvailability, listBookableStaff, releaseStaleSlots };
}
module.exports = { createSchedulingHandlers, dateKey, dayStart };
