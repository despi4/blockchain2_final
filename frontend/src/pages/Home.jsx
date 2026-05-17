import { useEffect, useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import {
  ADDRESSES,
  AMM_ABI,
  ERC20_ABI,
  GOVERNANCE_TOKEN_ABI,
  LP_TOKEN_ABI,
  VAULT_ABI,
  isConfiguredAddress,
} from "../config/contracts";
import { fetchRecentSwaps } from "../config/subgraph";
import ConfigNotice from "../components/ConfigNotice";
import { parseContractError } from "../hooks/useToast";
import { formatToken, shortAddress, timestampToLocal } from "../utils/format";

function StatCard({ label, value, sub }) {
  return (
    <div className="card">
      <div className="card-title">{label}</div>
      <div className="card-value">{value ?? <span className="spinner" />}</div>
      {sub && <div className="text-sm text-muted mt-1">{sub}</div>}
    </div>
  );
}

export default function Home({ toast }) {
  const { address, isConnected } = useAccount();
  const [delegatee, setDelegatee] = useState("");
  const [recentSwaps, setRecentSwaps] = useState(null);
  const [swapsError, setSwapsError] = useState(false);

  const configured = {
    governance: isConfiguredAddress(ADDRESSES.GOVERNANCE_TOKEN),
    gold: isConfiguredAddress(ADDRESSES.GOLD_TOKEN),
    amm: isConfiguredAddress(ADDRESSES.AMM),
    vault: isConfiguredAddress(ADDRESSES.VAULT),
  };

  const { data: tokenBalance } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && configured.governance },
  });

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "getVotes",
    args: [address],
    query: { enabled: !!address && configured.governance },
  });

  const { data: delegateAddress } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "delegates",
    args: [address],
    query: { enabled: !!address && configured.governance },
  });

  const { data: goldBalance } = useReadContract({
    address: ADDRESSES.GOLD_TOKEN,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && configured.gold },
  });

  const { data: reserves } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "getReserves",
    query: { enabled: configured.amm },
  });

  const { data: lpTokenAddress } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "lpToken",
    query: { enabled: configured.amm },
  });

  const { data: lpBalance } = useReadContract({
    address: lpTokenAddress,
    abi: LP_TOKEN_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && isConfiguredAddress(lpTokenAddress) },
  });

  const { data: vaultShares } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && configured.vault },
  });

  const { data: vaultAssets } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "totalAssets",
    query: { enabled: configured.vault },
  });

  const {
    writeContract,
    data: delegateHash,
    isPending: delegatePending,
    error: delegateError,
  } = useWriteContract();

  const { isLoading: delegateConfirming, isSuccess: delegateSuccess } =
    useWaitForTransactionReceipt({
      hash: delegateHash,
    });

  useEffect(() => {
    if (delegateSuccess) toast?.success("Delegation confirmed.");
  }, [delegateSuccess, toast]);

  useEffect(() => {
    if (delegateError) toast?.error(parseContractError(delegateError));
  }, [delegateError, toast]);

  useEffect(() => {
    fetchRecentSwaps(5)
      .then((data) => setRecentSwaps(data?.swaps ?? []))
      .catch(() => {
        setSwapsError(true);
        setRecentSwaps([]);
      });
  }, []);

  const handleDelegate = () => {
    const target = delegatee.trim() || address;
    if (!target) {
      toast?.error("Connect wallet first.");
      return;
    }

    writeContract({
      address: ADDRESSES.GOVERNANCE_TOKEN,
      abi: GOVERNANCE_TOKEN_ABI,
      functionName: "delegate",
      args: [target],
    });
  };

  const missingConfig = [];
  if (!configured.governance) missingConfig.push("Set VITE_GOVERNANCE_TOKEN_ADDRESS.");
  if (!configured.gold) missingConfig.push("Set VITE_GOLD_TOKEN_ADDRESS.");
  if (!configured.amm) missingConfig.push("Set VITE_AMM_ADDRESS.");
  if (!configured.vault) missingConfig.push("Set VITE_VAULT_ADDRESS.");

  return (
    <div className="page">
      <h1 className="page-title">Balance Dashboard</h1>

      <ConfigNotice title="Frontend contract config" lines={missingConfig} />

      <div className="grid-3 section-gap">
        <StatCard
          label="Governance Balance"
          value={isConnected ? `${formatToken(tokenBalance)} gGAME` : "Connect wallet"}
        />
        <StatCard
          label="Gold Balance"
          value={isConnected ? `${formatToken(goldBalance)} GOLD` : "Connect wallet"}
        />
        <StatCard
          label="Voting Power"
          value={isConnected ? `${formatToken(votingPower)} votes` : "Connect wallet"}
          sub={delegateAddress ? `Delegate: ${shortAddress(delegateAddress)}` : null}
        />
      </div>

      <div className="grid-3 section-gap">
        <StatCard
          label="Vault Shares"
          value={isConnected ? formatToken(vaultShares) : "Connect wallet"}
        />
        <StatCard label="Vault Assets" value={formatToken(vaultAssets)} />
        <StatCard
          label="LP Balance"
          value={isConnected ? formatToken(lpBalance) : "Connect wallet"}
        />
      </div>

      <div className="card section-gap">
        <div className="card-title">Core Protocol State</div>
        <div className="grid-2 mt-1">
          <div>
            <div className="stat-row">
              <span className="label">AMM Reserve 0</span>
              <span className="value">{reserves ? formatToken(reserves[0]) : "--"}</span>
            </div>
            <div className="stat-row">
              <span className="label">AMM Reserve 1</span>
              <span className="value">{reserves ? formatToken(reserves[1]) : "--"}</span>
            </div>
          </div>
          <div>
            <div className="stat-row">
              <span className="label">Governor Token</span>
              <span className="value mono">{shortAddress(ADDRESSES.GOVERNANCE_TOKEN)}</span>
            </div>
            <div className="stat-row">
              <span className="label">Treasury Vault</span>
              <span className="value mono">{shortAddress(ADDRESSES.VAULT)}</span>
            </div>
          </div>
        </div>
      </div>

      {isConnected && configured.governance && (
        <div className="card section-gap">
          <div className="card-title">Delegate Voting Power</div>
          <p className="text-sm text-muted mt-1" style={{ marginBottom: "0.75rem" }}>
            Delegate to yourself or another address to activate voting checkpoints.
          </p>
          <div style={{ display: "flex", gap: "0.75rem" }}>
            <input
              value={delegatee}
              onChange={(event) => setDelegatee(event.target.value)}
              placeholder="Delegate address (blank = self)"
              style={{ flex: 1 }}
            />
            <button
              className="btn-primary"
              disabled={delegatePending || delegateConfirming}
              onClick={handleDelegate}
            >
              {delegatePending || delegateConfirming ? "Delegating..." : "Delegate"}
            </button>
          </div>
        </div>
      )}

      <div className="card">
        <div className="flex-between" style={{ marginBottom: "0.75rem" }}>
          <div className="card-title" style={{ margin: 0 }}>
            Recent Swaps
          </div>
          <span className="text-sm text-muted">via The Graph</span>
        </div>
        {swapsError && (
          <p className="text-sm text-muted">
            Subgraph unavailable. Set VITE_SUBGRAPH_URL to a live deployment.
          </p>
        )}
        {!swapsError && recentSwaps === null && <span className="spinner" />}
        {!swapsError && recentSwaps?.length === 0 && (
          <p className="text-sm text-muted">No indexed swaps found yet.</p>
        )}
        {!swapsError && recentSwaps?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Sender</th>
                <th>In</th>
                <th>Out</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {recentSwaps.map((swap) => (
                <tr key={swap.id}>
                  <td className="mono">{shortAddress(swap.sender)}</td>
                  <td className="mono">{`${formatToken(BigInt(swap.amountIn))} ${shortAddress(swap.tokenIn)}`}</td>
                  <td className="mono">{`${formatToken(BigInt(swap.amountOut))} ${shortAddress(swap.tokenOut)}`}</td>
                  <td className="text-sm text-muted">{timestampToLocal(swap.timestamp)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
