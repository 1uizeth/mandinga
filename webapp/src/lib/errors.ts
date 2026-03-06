/**
 * Error handling utilities for wallet and RPC errors.
 * EH-001: RPC errors show user-friendly message and retry option
 * EH-002: Insufficient balance shows clear message
 * EH-003: User rejection (cancel) does not show as error
 */

export function isUserRejection(error: Error | null | undefined): boolean {
  if (!error) return false;
  const msg = error.message?.toLowerCase() ?? "";
  const code = (error as { code?: number }).code;
  const name = (error as { name?: string }).name ?? "";
  return (
    code === 4001 ||
    name === "UserRejectedRequestError" ||
    msg.includes("user rejected") ||
    msg.includes("user denied") ||
    msg.includes("rejected the request")
  );
}

export function isInsufficientBalance(error: Error | null | undefined): boolean {
  if (!error) return false;
  const msg = error.message?.toLowerCase() ?? "";
  return (
    msg.includes("insufficient") ||
    msg.includes("exceeds balance") ||
    msg.includes("balance too low")
  );
}

export function isRpcError(error: Error | null | undefined): boolean {
  if (!error) return false;
  const msg = error.message?.toLowerCase() ?? "";
  const name = (error as { name?: string }).name ?? "";
  return (
    name === "NetworkError" ||
    name === "TimeoutError" ||
    msg.includes("network") ||
    msg.includes("rpc") ||
    msg.includes("fetch") ||
    msg.includes("timeout") ||
    msg.includes("connection")
  );
}

export function getErrorMessage(error: Error | null | undefined): string {
  if (!error) return "Something went wrong. Please try again.";
  if (isUserRejection(error)) {
    return "Transaction cancelled. You rejected the request in your wallet.";
  }
  if (isInsufficientBalance(error)) {
    return "Insufficient USDC balance. Please ensure you have enough USDC to complete this transaction.";
  }
  if (isRpcError(error)) {
    return "Network error. Please check your connection and try again.";
  }
  return "Something went wrong. Please try again.";
}
