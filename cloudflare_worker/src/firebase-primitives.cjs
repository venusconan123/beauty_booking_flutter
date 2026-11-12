'use strict';
// Small wire-compatible primitives for the shared business handlers on Workers.
// Firebase Admin itself stays on the Node/Functions test path.
class Timestamp {
  constructor(seconds, nanoseconds = 0) { this.seconds = seconds; this.nanoseconds = nanoseconds; }
  static fromMillis(ms) { const seconds = Math.floor(ms / 1000); return new Timestamp(seconds, Math.round((ms - seconds * 1000) * 1e6)); }
  toMillis() { return this.seconds * 1000 + this.nanoseconds / 1e6; }
  toDate() { return new Date(this.toMillis()); }
}
class HttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
module.exports = { Timestamp, HttpsError, FieldValue: { serverTimestamp: () => ({ __serverTimestamp: true }) } };
