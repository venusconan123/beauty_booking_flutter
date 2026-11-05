'use strict';
const { HttpsError } = require('firebase-functions/v2/https');
const { FieldValue } = require('firebase-admin/firestore');
const SALONS = new Set(['salon_01', 'salon_02', 'salon_03']);

function identifier(value, field) {
  if (typeof value !== 'string' || !value.trim() || value.length > 128 || value.includes('/') || ['.', '..'].includes(value.trim())) {
    throw new HttpsError('invalid-argument', `${field} không hợp lệ.`);
  }
  return value.trim();
}

// Both directions are immutable in phase one, including inactive links.
// This prevents a stale session from inheriting another employee's assignments.
function createStaffHandlers(db, auth) {
  async function requireAdmin(request) {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập.');
    const user = await auth.getUser(request.auth.uid);
    if (user.disabled || !(await db.doc(`admins/${user.uid}`).get()).exists) {
      throw new HttpsError('permission-denied', 'Chỉ quản trị viên được thực hiện.');
    }
    return user.uid;
  }

  async function linkStaffAccount(request) {
    const actor = await requireAdmin(request);
    const uid = identifier(request.data?.uid, 'UID');
    const employeeId = identifier(request.data?.employeeId, 'Nhân viên');
    let user;
    try { user = await auth.getUser(uid); }
    catch (error) {
      if (error.code === 'auth/user-not-found') throw new HttpsError('not-found', 'Tài khoản Auth chưa tồn tại.');
      throw error;
    }
    if (user.disabled) throw new HttpsError('failed-precondition', 'Tài khoản Auth đã ngừng hoạt động.');
    if (!user.emailVerified) throw new HttpsError('failed-precondition', 'Tài khoản cần xác minh email trước khi liên kết.');
    return db.runTransaction(async (tx) => {
      const employeeRef = db.doc(`employees/${employeeId}`);
      const accountRef = db.doc(`staff_accounts/${uid}`);
      const linkRef = db.doc(`employee_accounts/${employeeId}`);
      const [admin, employee, account, link] = await tx.getAll(
        db.doc(`admins/${actor}`), employeeRef, accountRef, linkRef,
      );
      if (!admin.exists) throw new HttpsError('permission-denied', 'Quyền quản trị đã thay đổi.');
      if (!employee.exists) throw new HttpsError('not-found', 'Không tìm thấy hồ sơ nhân viên.');
      const profile = employee.data();
      if (('isActive' in profile && profile.isActive !== true) || !SALONS.has(profile.salonId)) {
        throw new HttpsError('failed-precondition', 'Nhân viên phải hoạt động và thuộc một chi nhánh hợp lệ.');
      }
      if (account.exists || link.exists) {
        if (account.data()?.employeeId === employeeId && link.data()?.uid === uid) {
          return { uid, employeeId, alreadyLinked: true };
        }
        throw new HttpsError('already-exists', 'UID hoặc nhân viên đã được liên kết.');
      }
      const timestamp = FieldValue.serverTimestamp();
      tx.create(accountRef, { employeeId, active: true, createdAt: timestamp, updatedAt: timestamp, updatedBy: actor });
      tx.create(linkRef, { uid, createdAt: timestamp });
      tx.create(db.collection('audit_events').doc(), {
        action: 'staff.link', actorUid: actor, targetUid: uid, employeeId, createdAt: timestamp,
      });
      return { uid, employeeId, alreadyLinked: false };
    });
  }

  async function setStaffAccountActive(request) {
    const actor = await requireAdmin(request);
    const uid = identifier(request.data?.uid, 'UID');
    if (typeof request.data?.active !== 'boolean') throw new HttpsError('invalid-argument', 'active phải là boolean.');
    const active = request.data.active;
    if (active) {
      const user = await auth.getUser(uid);
      if (user.disabled || !user.emailVerified) {
        throw new HttpsError('failed-precondition', 'Tài khoản Auth phải hoạt động và đã xác minh email.');
      }
    }
    return db.runTransaction(async (tx) => {
      const ref = db.doc(`staff_accounts/${uid}`);
      const [admin, account] = await tx.getAll(db.doc(`admins/${actor}`), ref);
      if (!admin.exists) throw new HttpsError('permission-denied', 'Quyền quản trị đã thay đổi.');
      if (!account.exists) throw new HttpsError('not-found', 'Tài khoản chưa liên kết.');
      const employeeId = account.data().employeeId;
      const [employee, link] = await tx.getAll(db.doc(`employees/${employeeId}`), db.doc(`employee_accounts/${employeeId}`));
      if (!link.exists || link.data().uid !== uid) throw new HttpsError('failed-precondition', 'Liên kết không nhất quán.');
      if (active && (!employee.exists ||
          ('isActive' in employee.data() && employee.data().isActive !== true) ||
          !SALONS.has(employee.data().salonId))) {
        throw new HttpsError('failed-precondition', 'Hồ sơ nhân viên không còn hoạt động hợp lệ.');
      }
      if (account.data().active === active) return { uid, active, unchanged: true };
      const timestamp = FieldValue.serverTimestamp();
      tx.update(ref, { active, updatedAt: timestamp, updatedBy: actor });
      tx.create(db.collection('audit_events').doc(), {
        action: active ? 'staff.activate' : 'staff.deactivate', actorUid: actor,
        targetUid: uid, employeeId, createdAt: timestamp,
      });
      return { uid, active, unchanged: false };
    });
  }
  return { linkStaffAccount, setStaffAccountActive };
}
module.exports = { createStaffHandlers };
