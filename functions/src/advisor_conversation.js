'use strict';
const normalize = value => String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/đ/g, 'd');
const ACTIONS = new Set(['find_staff', 'search_all', 'choose_service', 'choose_employee_date', 'choose_branch', 'choose_style_details']);
function conversationTurns(data) {
  const turns = data.conversation || data.context?.conversation;
  return Array.isArray(turns) ? turns.filter(turn => turn && ['user', 'assistant'].includes(turn.role) && typeof turn.content === 'string')
    .slice(-6).map(turn => ({ role: turn.role, content: turn.content.slice(0, 900) })) : [];
}
function pendingAction(value, services) {
  if (!value || !ACTIONS.has(value.type)) return null;
  return { type: value.type, question: typeof value.question === 'string' ? value.question.slice(0, 400) : '',
    serviceIds: Array.isArray(value.serviceIds) ? value.serviceIds.filter(id => services.some(s => s.id === id)).slice(0, 5) : [] };
}
function shortReplyIntent(message, context) {
  const text = normalize(message).replace(/[.!?,;]+/g, '').trim();
  if (/^(khong|khong can|thoi|chua can|khong nhe|no)$/.test(text)) {
    return { topic: 'clarify', serviceIds: [], declined: true, clarification: 'Được nhé. Bạn muốn mình hỗ trợ phần nào khác: chọn kiểu tóc, tìm thợ hay xem lịch?' };
  }
  if (!/^(co|co nhe|co a|co tim tho cat toc giup toi|vang|vang a|u|um|uh|duoc|duoc nhe|duoc ban|dong y|toi dong y|ok|ok ban|oke|okay|dung|dung roi|yes)$/.test(text)) return null;
  const action = context.pendingAction;
  if (action && ['find_staff', 'search_all'].includes(action.type) && action.serviceIds.length) {
    return { topic: 'expertise', serviceIds: action.serviceIds, allBranches: action.type === 'search_all' };
  }
  return { topic: 'clarify', serviceIds: [], clarification: action?.type === 'choose_service'
    ? 'Bạn muốn mình tìm thợ cho dịch vụ nào: cắt tóc, uốn hay nhuộm?' : action?.question ||
    'Bạn muốn mình tiếp tục phần nào: chọn kiểu tóc, tìm thợ phù hợp hay kiểm tra lịch trống?' };
}
function faceShape(message, previous) {
  const text = normalize(message);
  for (const [keyword, shape] of [['mat tron', 'round'], ['mat vuong', 'square'], ['mat dai', 'long'], ['trai xoan', 'oval']]) {
    if (text.includes(keyword)) return shape;
  }
  return ['round', 'square', 'long', 'oval'].includes(previous) ? previous : null;
}
function styleQuestion(message) {
  const text = normalize(message);
  return /mau toc|kieu toc|khuon mat|mat (tron|vuong|dai|trai xoan)|toc (mong|day|mem|cung)/.test(text) &&
    !/gia |bao nhieu tien|tho nao|nhan vien|lich trong|gio trong/.test(text);
}
function styleCandidates(styles, shape) {
  const keys = shape === 'round' ? ['quiff', 'side part', 'pompadour', 'undercut'] :
    shape === 'long' ? ['layer', 'crop', 'side part'] : ['side part', 'quiff', 'layer', 'crop'];
  return styles.map(style => ({ ...style, score: keys.reduce((n, key, i) => n + (normalize(style.name).includes(key) ? keys.length - i : 0), 0) }))
    .filter(s => s.score > 0).sort((a, b) => b.score - a.score || a.name.localeCompare(b.name)).slice(0, 3)
    .map(({ score, ...style }) => style);
}
module.exports = { conversationTurns, pendingAction, shortReplyIntent, faceShape, styleQuestion, styleCandidates };
