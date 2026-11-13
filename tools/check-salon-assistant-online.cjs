'use strict';
// Live read-only chatbot/availability checks. A temporary unprivileged Auth
// account is removed in finally; no appointments, shifts, reviews or money change.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const apiKey = fs.readFileSync(path.join(__dirname, '../lib/firebase_options.dart'), 'utf8').match(/apiKey:\s*'([^']+)'/)?.[1];
const base = 'https://men-hair-booking-vnpay.venusconan23.workers.dev/api/scheduling';
const identity = 'https://identitytoolkit.googleapis.com/v1/accounts';
async function post(url, body, token) {
  const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body), signal: AbortSignal.timeout(60000) });
  const value = await response.json();
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${value.error?.message || 'Request failed'}`);
  return value;
}
async function main() {
  let token;
  try {
    if (!apiKey) throw Error('Firebase web configuration missing');
    const signup = await post(`${identity}:signUp?key=${apiKey}`, { email: `ai-check-${crypto.randomUUID()}@example.test`,
      password: crypto.randomBytes(24).toString('base64url'), returnSecureToken: true });
    token = signup.idToken;
    const call = async (method, data) => (await post(`${base}/${method}`, { data }, token)).result;
    const today = new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10);
    // An existing demo roster date, if future; otherwise tomorrow. No fixture is created.
    const date = today < '2026-12-19' ? '2026-12-19' : new Date(Date.now() + 31 * 3600000).toISOString().slice(0, 10);
    const dayText = date.split('-').reverse().join('/');
    const questions = [
      { message: 'Uốn tóc bao nhiêu tiền, làm bao lâu?' },
      { message: `Ngày ${dayText} tôi muốn uốn tóc ở chi nhánh Nguyễn Văn Linh thì có thợ nào phù hợp?` },
    ];
    const checks = [];
    let previous;
    for (const question of questions) {
      const reply = await call('askSalonAssistant', question);
      assert.equal(reply.source, 'firebase-live');
      assert.equal(reply.aiProvider, 'cloudflare-workers-ai');
      assert.ok(reply.services.some(s => /uốn/i.test(s.name)), 'AI must identify the requested perm service');
      assert.ok(!JSON.stringify(reply).match(/"(?:phone|email|userId|payment|bookings)"\s*:/), 'No private fields');
      if (question === questions[1]) {
        assert.equal(reply.context.salonId, 'salon_01');
        assert.equal(reply.context.dateKey, date);
        const availability = await call('getAvailability', { salonId: 'salon_01', dateKey: date, serviceIds: reply.context.serviceIds });
        assert.equal(reply.price, availability.price, `Price for booking request, context=${JSON.stringify(reply.context)}`);
        assert.equal(reply.durationMinutes, availability.durationMinutes);
        for (const person of reply.recommendations) {
          assert.ok(person.times.length);
          for (const time of person.times) assert.ok(availability.slots.some(s => s.time === time && s.employeeIds.includes(person.employeeId)));
        }
        previous = reply;
      } else {
        const availability = await call('getAvailability', { salonId: 'salon_01', dateKey: date, serviceIds: reply.services.map(s => s.id) });
        assert.equal(reply.services.reduce((sum, s) => sum + s.price, 0), availability.price);
        assert.equal(reply.services.reduce((sum, s) => sum + s.durationMinutes, 0), availability.durationMinutes);
      }
      checks.push({ question: question.message, context: reply.context, message: reply.message, wording: reply.wording,
        recommendations: reply.recommendations.map(p => ({ name: p.name, matchingServices: p.matchingServices, times: p.times })), passed: true });
    }
    const followup = await call('askSalonAssistant', { message: 'Buổi chiều thì sao?', context: previous.context, history: [questions[1].message] });
    assert.equal(followup.context.salonId, 'salon_01');
    assert.equal(followup.context.dateKey, date);
    assert.deepEqual(followup.context.serviceIds, previous.context.serviceIds);
    assert.equal(followup.context.timeFrom, '12:00');
    for (const person of followup.recommendations) assert.ok(person.times.every(t => t >= '12:00' && t <= '17:30'));
    checks.push({ question: 'Buổi chiều thì sao?', context: followup.context, message: followup.message, passed: true });
    const schedule = await call('askSalonAssistant', { message: `Nhân viên Lê Quốc làm ca nào ngày ${dayText} ở Nguyễn Văn Linh?` });
    assert.equal(schedule.context.topic, 'schedule');
    assert.ok(schedule.recommendations.every(p => p.name.includes('Lê Quốc') && p.periods.length));
    checks.push({ question: 'Ca làm của Lê Quốc', context: schedule.context,
      recommendations: schedule.recommendations.map(p => ({ name: p.name, periods: p.periods })), passed: true });
    const expertise = await call('askSalonAssistant', { message: 'Tôi muốn tra cứu khi tôi uốn tóc thì có thợ nào phù hợp?',
      context: { salonId: 'salon_01', dateKey: today, serviceIds: ['service_perm'], topic: 'recommend' },
      history: ['Hôm nay có giờ trống không?'] });
    assert.equal(expertise.context.topic, 'expertise');
    assert.equal(expertise.recommendationKind, 'expertise');
    assert.equal(expertise.availabilityStatus, 'not_checked');
    assert.ok(!/hết lịch|kín lịch|Không còn giờ trống/i.test(expertise.message));
    assert.ok(expertise.recommendations.every(p => p.matchingServices.length > 0));
    checks.push({ question: 'Thợ nào phù hợp, không áp điều kiện lịch hôm nay', context: expertise.context,
      message: expertise.message, wording: expertise.wording, passed: true });
    const allBranches = await call('askSalonAssistant', { message: 'Tìm thợ chuyên uốn tóc ở cả ba chi nhánh', context: expertise.context });
    assert.equal(allBranches.context.salonId, null);
    assert.equal(allBranches.context.topic, 'expertise');
    assert.ok(allBranches.recommendations.every(p => p.matchingServices.length > 0 && p.salonName));
    checks.push({ question: 'Tìm chuyên môn ở cả ba chi nhánh', context: allBranches.context, message: allBranches.message,
      wording: allBranches.wording, recommendations: allBranches.recommendations.map(p => ({ name: p.name, salonName: p.salonName, matchingServices: p.matchingServices })), passed: true });
    assert.ok(checks.some(check => check.wording === 'ai'), 'Conversational AI prose must be exercised online');
    const styleQuestion = 'Tôi mặt tròn thì hợp với mẫu tóc nào?';
    const style = await call('askSalonAssistant', { message: styleQuestion, context: { salonId: 'salon_01', dateKey: today } });
    assert.equal(style.context.topic, 'style');
    assert.equal(style.context.faceShape, 'round');
    assert.deepEqual(style.context.serviceIds, []);
    assert.equal(style.context.pendingAction.type, 'find_staff');
    assert.ok(!/\b(?:bob|lob)\b/i.test(style.message));
    assert.ok(style.message.endsWith(style.followUpQuestion));
    const confirmed = await call('askSalonAssistant', { message: 'có', context: style.context,
      conversation: [{ role: 'user', content: styleQuestion }, { role: 'assistant', content: style.message }] });
    assert.equal(confirmed.context.topic, 'expertise');
    assert.deepEqual(confirmed.context.serviceIds, style.context.pendingAction.serviceIds);
    assert.ok(!confirmed.context.serviceIds.includes('service_perm') && !confirmed.context.serviceIds.includes('service_dye'));
    assert.ok(!/250[.,]000|300[.,]000/.test(confirmed.message));
    checks.push({ question: `${styleQuestion} → có`, styleMessage: style.message, pending: style.context.pendingAction,
      confirmationMessage: confirmed.message, context: confirmed.context, passed: true });
    const ambiguous = await call('askSalonAssistant', { message: 'có', context: {} });
    assert.equal(ambiguous.context.topic, 'clarify');
    assert.deepEqual(ambiguous.context.serviceIds, []);
    checks.push({ question: 'Có, không có câu hỏi trước', message: ambiguous.message, passed: true });
    console.log(JSON.stringify({ project: 'men-hair-booking', checks, bookingOrRosterWrites: false }, null, 2));
  } finally {
    if (token) {
      await post(`${identity}:delete?key=${apiKey}`, { idToken: token });
      console.log('Temporary chatbot-check account removed.');
    }
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
