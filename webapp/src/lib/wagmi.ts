import { http, createConfig } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { injected } from "wagmi/connectors";

export const config = createConfig({
  chains: [baseSepolia],
  connectors: [injected()],
  ssr: true,
  transports: {
    [baseSepolia.id]: http(
      process.env.NEXT_PUBLIC_RPC_URL ?? "https://base-sepolia-rpc.publicnode.com"
    ),
  },
});
