/**
 * Spec 006 FR-004: Graceful handling of contract failures.
 * Retry with exponential backoff, alert on failure.
 */

export interface RetryOptions {
  maxRetries?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
}

const DEFAULT_OPTIONS: Required<RetryOptions> = {
  maxRetries: 3,
  baseDelayMs: 1000,
  maxDelayMs: 30000,
};

function delay(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

/**
 * Execute fn with exponential backoff retry.
 * Throws last error after maxRetries exhausted.
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const { maxRetries, baseDelayMs, maxDelayMs } = {
    ...DEFAULT_OPTIONS,
    ...options,
  };
  let lastError: unknown;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (attempt < maxRetries) {
        const delayMs = Math.min(
          baseDelayMs * 2 ** attempt,
          maxDelayMs
        );
        console.warn(`Attempt ${attempt + 1} failed, retrying in ${delayMs}ms:`, err);
        await delay(delayMs);
      }
    }
  }
  throw lastError;
}

/**
 * Alert on failure (console or external hook).
 * Replace with indexer event / push notification in production.
 */
export function alertOnFailure(
  context: string,
  error: unknown,
  metadata?: Record<string, unknown>
): void {
  console.error(`[ALERT] ${context}`, error, metadata ?? {});
  // TODO: Integrate with alerting (PagerDuty, Slack, indexer event)
}
