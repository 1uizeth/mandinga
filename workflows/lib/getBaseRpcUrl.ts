/**
 * Base RPC URL for CRE workflows.
 * Chain names: ethereum-testnet-sepolia-base-1, ethereum-mainnet-base-1
 */
export function getBaseRpcUrl(chainName: string): string {
  const urls: Record<string, string> = {
    "ethereum-testnet-sepolia-base-1": "https://base-sepolia-rpc.publicnode.com",
    "ethereum-mainnet-base-1": "https://mainnet.base.org",
  };
  const url = urls[chainName];
  if (!url) {
    throw new Error(`Unknown chain: ${chainName}`);
  }
  return process.env[`RPC_${chainName.replace(/-/g, "_").toUpperCase()}`] ?? url;
}
