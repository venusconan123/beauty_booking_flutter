'use strict';
const { requireWrites } = require('./write_control');
const { HttpsError } = require('firebase-functions/v2/https');
const { FieldValue } = require('firebase-admin/firestore');
const { createHash } = require('node:crypto');
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
    return linkUser(actor, user, employeeId);
  }

  async function linkUser(actor, user, employeeId, provisioning = false) {
    const uid = user.uid;
    return db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'staffWritesEnabled');
      const employeeRef = db.doc(`employees/${employeeId}`);
      const accountRef = db.doc(`staff_accounts/${uid}`);
      const linkRef = db.doc(`employee_accounts/${employeeId}`);
      const [admin, employee, account, link, targetAdmin] = await tx.getAll(
        db.doc(`admins/${actor}`), employeeRef, accountRef, linkRef, db.doc(`admins/${uid}`),
      );
      if (!admin.exists) throw new HttpsError('permission-denied', 'Quyền quản trị đã thay đổi.');
      if (targetAdmin.exists) throw new HttpsError('failed-precondition', 'Email quản trị không thể dùng làm tài khoản nhân viên.');
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
      tx.create(accountRef, { employeeId, email: user.email, active: true, createdAt: timestamp, updatedAt: timestamp, updatedBy: actor });
      tx.create(linkRef, { uid, createdAt: timestamp });
      tx.create(db.collection('audit_events').doc(), {
        action: provisioning ? 'staff.provision' : 'staff.link', actorUid: actor, targetUid: uid, employeeId, createdAt: timestamp,
      });
      return { uid, employeeId, alreadyLinked: false };
    });
  }

  async function createStaffAccount(request) {
    const actor = await requireAdmin(request);
    const employeeId = identifier(request.data?.employeeId, 'Nhân viên');
    const email = typeof request.data?.email === 'string' ? request.data.email.trim().toLowerCase() : '';
    if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'Email không hợp lệ.');
    }
    // Check the switch and employee BEFORE any Auth side effect, then recheck
    // both when committing the role. No password is saved in Firestore or logs.
    const employee = await db.runTransaction(async (tx) => {
      await requireWrites(tx, db, 'staffWritesEnabled');
      const [admin, profile, link] = await tx.getAll(db.doc(`admins/${actor}`),
        db.doc(`employees/${employeeId}`), db.doc(`employee_accounts/${employeeId}`));
      if (!admin.exists) throw new HttpsError('permission-denied', 'Quyền quản trị đã thay đổi.');
      if (!profile.exists) throw new HttpsError('not-found', 'Không tìm thấy hồ sơ nhân viên.');
      const data = profile.data();
      if (('isActive' in data && data.isActive !== true) || !SALONS.has(data.salonId)) {
        throw new HttpsError('failed-precondition', 'Nhân viên phải đang hoạt động tại chi nhánh hợp lệ.');
      }
      return { ...data, linkedUid: link.data()?.uid };
    });
    // Provisioning never upgrades an existing customer/Auth identity to staff.
    try {
      await auth.getUserByEmail(email);
      throw new HttpsError('already-exists', 'Email này đã được sử dụng.');
    }
    catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    if (employee.linkedUid) throw new HttpsError('already-exists', 'Nhân viên đã có tài khoản. Không tạo thêm tài khoản.');
    const password = request.data?.password;
    if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
      throw new HttpsError('invalid-argument', 'Mật khẩu ban đầu cần từ 8 đến 128 ký tự.');
    }
    // Stable employee UID also prevents two concurrent emails from provisioning
    // separate identities for one employee. Firebase enforces email uniqueness.
    const uid = `staff-${createHash('sha256').update(employeeId).digest('hex').slice(0, 40)}`;
    let user;
    try {
      user = await auth.createUser({ uid, email, password, emailVerified: false,
        displayName: employee.name || 'Nhân viên' });
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        throw new HttpsError('already-exists', 'Email này đã được sử dụng.');
      }
      if (error.code !== 'auth/uid-already-exists') throw error;
      // This lookup only chooses the error message; NEVER link an existing user,
      // including a customer that registered between lookup and createUser.
      let emailExists = true;
      try { await auth.getUserByEmail(email); }
      catch (lookupError) {
        if (lookupError.code !== 'auth/user-not-found') throw lookupError;
        emailExists = false;
      }
      throw new HttpsError('already-exists', emailExists
        ? 'Email này đã được sử dụng.' : 'Nhân viên đã có tài khoản. Không tạo thêm tài khoản.');
    }
    const result = await linkUser(actor, user, employeeId, true);
    return { ...result, email, created: true, requiresEmailVerification: !user.emailVerified };
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
      await requireWrites(tx, db, 'staffWritesEnabled');
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
  return { createStaffAccount, linkStaffAccount, setStaffAccountActive };
}
module.exports = { createStaffHandlers };
