import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { arbitrumSepolia } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "GameFi Economy",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "af5429c018ee5ba8fe48cbccc39ef38f",
  chains: [arbitrumSepolia],
  ssr: false,
});

export const TARGET_CHAIN_ID = arbitrumSepolia.id;
export const TARGET_CHAIN_NAME = "Arbitrum Sepolia";
