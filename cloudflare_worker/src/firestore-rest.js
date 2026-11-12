import primitives from './firebase-primitives.cjs';
const { Timestamp } = primitives;

export function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date || typeof value?.toDate === 'function') {
    const date = value instanceof Date ? value : value.toDate();
    return { timestampValue: date.toISOString() };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number' && Number.isFinite(value)) return Number.isInteger(value)
    ? { integerValue: String(value) } : { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (value && typeof value === 'object') return { mapValue: { fields: encodeFields(value) } };
  throw new Error('Unsupported Firestore value');
}
export const encodeFields = (data) => Object.fromEntries(Object.entries(data).map(([key, value]) => [key, encodeValue(value)]));
export function decodeValue(value) {
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return Timestamp.fromMillis(Date.parse(value.timestampValue));
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('stringValue' in value) return value.stringValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decodeValue);
  if ('mapValue' in value) return decodeFields(value.mapValue.fields || {});
  throw new Error('Unsupported Firestore response');
}
export const decodeFields = (data) => Object.fromEntries(Object.entries(data).map(([key, value]) => [key, decodeValue(value)]));
const fieldPath = (parts) => parts.map((part) => /^[A-Za-z_][A-Za-z0-9_]*$/.test(part)
  ? part : '`' + part.replace(/\\/g, '\\\\').replace(/`/g, '\\`') + '`').join('.');
const serverTime = (value) => value?.__serverTimestamp === true || value?.constructor?.name === 'ServerTimestampTransform';

export function makeWrite(ref, data, mode, merge = false) {
  const fields = Object.create(null), transforms = [], mask = [];
  function walk(target, key, value, parts, flatten) {
    const path = fieldPath(parts);
    if (serverTime(value)) { transforms.push({ fieldPath: path, setToServerValue: 'REQUEST_TIME' }); return; }
    const map = value && typeof value === 'object' && !Array.isArray(value) &&
      !(value instanceof Date) && typeof value.toMillis !== 'function';
    if (map && Object.keys(value).length) {
      target[key] = { mapValue: { fields: Object.create(null) } };
      for (const [child, item] of Object.entries(value)) walk(target[key].mapValue.fields, child, item, [...parts, child], flatten);
      if (!flatten) mask.push(path);
    } else { target[key] = encodeValue(value); if (flatten) mask.push(path); }
  }
  for (const [name, value] of Object.entries(data)) {
    const parts = mode === 'update' ? name.split('.') : [name];
    let target = fields;
    for (const part of parts.slice(0, -1)) target = (target[part] ??= { mapValue: { fields: Object.create(null) } }).mapValue.fields;
    walk(target, parts.at(-1), value, parts, merge);
    if (!serverTime(value) && !merge) mask.push(fieldPath(parts));
  }
  const write = { update: { name: ref.name, fields } };
  if (mode === 'update' || merge) write.updateMask = { fieldPaths: [...new Set(mask)] };
  if (transforms.length) write.updateTransforms = transforms;
  if (mode === 'create') write.currentDocument = { exists: false };
  if (mode === 'update') write.currentDocument = { exists: true };
  return write;
}

class Reference {
  constructor(db, path) { this.db = db; this.path = path; this.id = path.split('/').at(-1); this.name = `${db.root}/${path}`; }
  get() { return this.db.read(this); }
}
class Query {
  constructor(db, path, filters = []) { this.db = db; this.path = path; this.filters = filters; }
  doc(id = crypto.randomUUID().replaceAll('-', '')) { return this.db.doc(`${this.path}/${id}`); }
  where(field, op, value) { return new Query(this.db, this.path, [...this.filters, [field, op, value]]); }
  get() { return this.db.query(this); }
}
const operators = { '==': 'EQUAL', '>=': 'GREATER_THAN_OR_EQUAL', '<': 'LESS_THAN', '<=': 'LESS_THAN_OR_EQUAL', '>': 'GREATER_THAN' };
const compare = (value, op, expected) => op === '==' ? value === expected : op === '>=' ? value >= expected :
  op === '<=' ? value <= expected : op === '<' ? value < expected : value > expected;

export class RestFirestore {
  constructor({ projectId, tokenProvider, baseUrl = 'https://firestore.googleapis.com/v1', fetchImpl = fetch, hints = {} }) {
    if (!/^[a-z][a-z0-9-]{4,62}$/.test(projectId)) throw new Error('Invalid project');
    this.projectId = projectId; this.root = `projects/${projectId}/databases/(default)/documents`;
    this.api = `${baseUrl}/${this.root}`; this.tokenProvider = tokenProvider;
    // Workers fetch is receiver-sensitive; calling an unbound copy as a class
    // method raises Illegal invocation although Node's fetch accepts it.
    this.fetchImpl = fetchImpl.bind(globalThis); this.hints = hints;
  }
  doc(path) {
    const parts = path.split('/');
    if (parts.length % 2 || parts.some((part) => !part || part === '.' || part === '..')) throw new Error('Invalid document path');
    return new Reference(this, path);
  }
  collection(path) { return new Query(this, path); }
  async rpc(suffix, body, method = 'POST') {
    const token = await this.tokenProvider();
    const response = await this.fetchImpl(`${this.api}${suffix}`, { method,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(25000) });
    const result = await response.json();
    if (!response.ok) {
      const error = new Error(`Firestore ${result.error?.status || response.status}`);
      error.status = response.status; error.code = result.error?.status; throw error;
    }
    return result;
  }
  snapshot(ref, document) {
    return { ref, id: ref.id, exists: !!document, data: () => document ? decodeFields(document.fields || {}) : undefined };
  }
  async read(ref, transaction) { return (await this.batch([ref], transaction))[0]; }
  async batch(refs, transaction) {
    if (!refs.length) return [];
    const result = await this.rpc(':batchGet', { documents: refs.map((ref) => ref.name), ...(transaction ? { transaction } : {}) });
    const rows = new Map(result.map((row) => [row.found?.name || row.missing, row.found]));
    return refs.map((ref) => this.snapshot(ref, rows.get(ref.name)));
  }
  getAll(...refs) { return this.batch(refs); }
  async query(query, transaction) {
    const parts = query.path.split('/'), collectionId = parts.pop();
    const filters = query.filters.map(([field, op, value]) => {
      if (!operators[op]) throw new Error('Unsupported query');
      return { fieldFilter: { field: { fieldPath: fieldPath([field]) }, op: operators[op], value: encodeValue(value) } };
    });
    const result = await this.rpc(`${parts.length ? '/' + parts.join('/') : ''}:runQuery`, {
      structuredQuery: { from: [{ collectionId }], ...(filters.length ? { where: filters.length === 1
        ? filters[0] : { compositeFilter: { op: 'AND', filters } } } : {}) }, ...(transaction ? { transaction } : {}),
    });
    const docs = result.filter((row) => row.document).map(({ document }) => this.snapshot(
      this.doc(document.name.slice(this.root.length + 1)), document));
    return { docs, empty: !docs.length, size: docs.length };
  }
  async runTransaction(operation) {
    for (let attempt = 0; attempt < 5; attempt++) {
      const { transaction } = await this.rpc(':beginTransaction', { options: { readWrite: {} } });
      const writes = [], cache = new Map(), queryCache = new Map(); let writing = false;
      const readAll = async (refs) => {
        if (writing) throw new Error('Transaction reads must precede writes');
        const missing = refs.filter((ref) => !cache.has(ref.path));
        if (missing.length) for (const row of await this.batch(missing, transaction)) cache.set(row.ref.path, row);
        return refs.map((ref) => cache.get(ref.path));
      };
      const tx = {
        getAll: (...refs) => readAll(refs),
        get: async (target) => {
          if (target instanceof Reference) return (await readAll([target]))[0];
          if (writing) throw new Error('Transaction reads must precede writes');
          // A roster request often reads each employee/date separately. Read that
          // employee's requested date range once in the SAME transaction, then
          // filter the snapshots. This preserves all booking/guard checks while
          // staying within the Workers Free subrequest limit.
          const employee = target.filters.find(([field, op]) => field === 'employeeId' && op === '==');
          const day = target.filters.find(([field, op]) => field === 'dateKey' && op === '==');
          let source = target;
          const dates = this.hints.dates;
          if (target.path === 'work_shifts' && employee && day && dates?.includes(day[2])) {
            source = this.collection(target.path).where('employeeId', '==', employee[2])
              .where('dateKey', '>=', dates[0]).where('dateKey', '<=', dates.at(-1));
          }
          const key = JSON.stringify([source.path, source.filters]);
          if (!queryCache.has(key)) queryCache.set(key, this.query(source, transaction));
          const all = await queryCache.get(key);
          const docs = all.docs.filter((doc) => target.filters.every(([field, op, value]) => compare(doc.data()[field], op, value)));
          return { docs, empty: !docs.length, size: docs.length };
        },
        create: (ref, data) => { writing = true; writes.push(makeWrite(ref, data, 'create')); },
        update: (ref, data) => { writing = true; writes.push(makeWrite(ref, data, 'update')); },
        set: (ref, data, options) => { writing = true; writes.push(makeWrite(ref, data, 'set', options?.merge)); },
      };
      try {
        if (this.hints.documents?.length) await readAll(this.hints.documents.map((path) => this.doc(path)));
        const result = await operation(tx);
        await this.rpc(':commit', { transaction, writes });
        return result;
      } catch (error) {
        await this.rpc(':rollback', { transaction }).catch(() => {});
        if (error.code !== 'ABORTED' || attempt === 4) throw error;
        await new Promise((resolve) => setTimeout(resolve, 30 + Math.random() * 80 * (attempt + 1)));
      }
    }
  }
}

export function rosterHints(data) {
  const cells = Array.isArray(data.cells) ? data.cells : (Array.isArray(data.dates) ? data.dates : []).map((dateKey) => ({ employeeId: data.employeeId, dateKey }));
  if (!Array.isArray(cells) || cells.length > 160) return {};
  const safe = cells.filter((cell) => /^[A-Za-z0-9_-]{1,128}$/.test(cell?.employeeId || '') && /^\d{4}-\d{2}-\d{2}$/.test(cell?.dateKey || ''));
  const dates = [...new Set(safe.map((cell) => cell.dateKey))].sort();
  return { dates, documents: [...new Set(safe.flatMap((cell) => [
    `employees/${cell.employeeId}`, `employee_days/${cell.employeeId}_${cell.dateKey}`,
  ]))] };
}
