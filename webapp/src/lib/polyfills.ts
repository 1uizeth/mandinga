/**
 * Polyfill indexedDB for SSR. Wagmi/RainbowKit dependencies use it,
 * but it's undefined in Node.js. This must run before any wallet code.
 * Minimal no-op mock to prevent "indexedDB is not defined" errors.
 */
if (typeof globalThis !== "undefined" && typeof globalThis.indexedDB === "undefined") {
  const noop = () => {};
  const mockRequest = {
    result: undefined,
    error: null,
    readyState: "done",
    addEventListener: noop,
    removeEventListener: noop,
    dispatchEvent: () => false,
  };
  (globalThis as Record<string, unknown>).indexedDB = {
    open: () => mockRequest,
    deleteDatabase: () => mockRequest,
    cmp: () => 0,
  };
}
