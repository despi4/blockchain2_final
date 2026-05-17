import { useChainId, useSwitchChain } from "wagmi";
import { TARGET_CHAIN_ID, TARGET_CHAIN_NAME } from "../config/wagmi";

export default function NetworkGuard() {
  const chainId = useChainId();
  const { switchChain, isPending } = useSwitchChain();

  if (!chainId || chainId === TARGET_CHAIN_ID) return null;

  return (
    <div className="network-banner">
      <span>Wrong network — please switch to {TARGET_CHAIN_NAME}</span>
      <button
        className="btn-primary"
        style={{ padding: "0.3rem 0.9rem", fontSize: "0.8rem" }}
        disabled={isPending}
        onClick={() => switchChain({ chainId: TARGET_CHAIN_ID })}
      >
        {isPending ? "Switching…" : "Switch Network"}
      </button>
    </div>
  );
}
