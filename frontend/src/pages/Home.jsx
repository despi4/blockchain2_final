import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits, isAddress } from "viem";
import {
  ADDRESSES,
  GOVERNANCE_TOKEN_ABI,
  AMM_ABI,
  VAULT_ABI,
} from "../config/contracts";
import { fetchRecentSwaps } from "../config/subgraph";
import { parseContractError } from "../hooks/useToast";

function StatCard({ label, value, sub }) {
  return (
    <div className="card">
      <div className="card-title">{label}</div>
      <div className="card-value">{value ?? <span className="spinner" />}</div>
      {sub && <div className="text-sm text-muted mt-1">{sub}</div>}
    </div>
  );
}

function fmt(val, decimals = 18, dp = 4) {
  if (val === undefined || val === null) return "—";
  const n = parseFloat(formatUnits(val, decimals));
  return n.toLocaleString(undefined, { maximumFractionDigits: dp });
}

function shortAddr(addr) {
  if (!addr || addr === "0x0000000000000000000000000000000000000000") return "None";
  return addr.slice(0, 6) + "…" + addr.slice(-4);
}

export default function Home({ toast }) {
  const { address, isConnected } = useAccount();
  const [delegatee, setDelegatee]   = useState("");
  const [recentSwaps, setRecentSwaps] = useState(null);
  const [swapsError,  setSwapsError]  = useState(false);

  // ── Contract reads ─────────────────────────────────────────────────────────
  const { data: tokenBalance } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi:     GOVERNANCE_TOKEN_ABI,
    functionName: "balanceOf",
    args:    [address],
    query:   { enabled: !!address },
  });

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi:     GOVERNANCE_TOKEN_ABI,
    functionName: "getVotes",
    args:    [address],
    query:   { enabled: !!address },
  });

  const { data: delegateAddr } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi:     GOVERNANCE_TOKEN_ABI,
    functionName: "delegates",
    args:    [address],
    query:   { enabled: !!address },
  });

  const { data: reserves } = useReadContract({
    address: ADDRESSES.AMM,
    abi:     AMM_ABI,
    functionName: "getReserves",
  });

  const { data: vaultAssets } = useReadContract({
    address: ADDRESSES.VAULT,
    abi:     VAULT_ABI,
    functionName: "totalAssets",
  });

  const { data: vaultShares } = useReadContract({
    address: ADDRESSES.VAULT,
    abi:     VAULT_ABI,
    functionName: "balanceOf",
    args:    [address],
    query:   { enabled: !!address },
  });

  // ── Delegate write ─────────────────────────────────────────────────────────
  const { writeContract, data: delegateTxHash, isPending: delegatePending, error: delegateError } = useWriteContract();
  const { isLoading: delegateConfirming, isSuccess: delegateSuccess } = useWaitForTransactionReceipt({ hash: delegateTxHash });

  useEffect(() => {
    if (delegateSuccess) toast?.success("Delegation confirmed!");
  }, [delegateSuccess]);

  useEffect(() => {
    if (delegateError) toast?.error(parseContractError(delegateError));
  }, [delegateError]);

  const handleDelegate = () => {
    const target = delegatee.trim() || address;
    if (!isAddress(target)) { toast?.error("Invalid address"); return; }
    writeContract({
      address: ADDRESSES.GOVERNANCE_TOKEN,
      abi:     GOVERNANCE_TOKEN_ABI,
      functionName: "delegate",
      args:    [target],
    });
  };

  // ── Subgraph: recent swaps ─────────────────────────────────────────────────
  useEffect(() => {
    fetchRecentSwaps(5)
      .then((d) => setRecentSwaps(d?.swaps ?? []))
      .catch(() => { setSwapsError(true); setRecentSwaps([]); });
  }, []);

  return (
    <div className="page">
      <div className="flex-between section-gap">
        <h1 className="page-title" style={{ margin: 0 }}>Dashboard</h1>
      </div>

      {/* ── Token Stats ─────────────────────────────────────────────────── */}
      <div className="grid-3 section-gap">
        <StatCard
          label="GOV Token Balance"
          value={isConnected ? fmt(tokenBalance) + " GOV" : "Connect wallet"}
        />
        <StatCard
          label="Voting Power"
          value={isConnected ? fmt(votingPower) + " votes" : "Connect wallet"}
          sub={delegateAddr ? `Delegated to: ${shortAddr(delegateAddr)}` : null}
        />
        <StatCard
          label="Vault Shares"
          value={isConnected ? fmt(vaultShares) + " vGFI" : "Connect wallet"}
          sub={vaultAssets !== undefined ? `Pool: ${fmt(vaultAssets)} assets` : null}
        />
      </div>

      {/* ── Pool Reserves ───────────────────────────────────────────────── */}
      <div className="card section-gap">
        <div className="card-title">AMM Pool Reserves</div>
        <div className="grid-2 mt-1">
          <div>
            <div className="stat-row">
              <span className="label">Reserve 0</span>
              <span className="value mono">
                {reserves ? fmt(reserves[0]) : "—"}
              </span>
            </div>
            <div className="stat-row">
              <span className="label">Reserve 1</span>
              <span className="value mono">
                {reserves ? fmt(reserves[1]) : "—"}
              </span>
            </div>
          </div>
          <div>
            <div className="stat-row">
              <span className="label">Total Vault Assets</span>
              <span className="value mono">{fmt(vaultAssets)}</span>
            </div>
            <div className="stat-row">
              <span className="label">Delegate Address</span>
              <span className="value mono">{shortAddr(delegateAddr)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Delegate ────────────────────────────────────────────────────── */}
      {isConnected && (
        <div className="card section-gap">
          <div className="card-title">Delegate Voting Power</div>
          <p className="text-sm text-muted mt-1" style={{ marginBottom: "0.75rem" }}>
            You must delegate to yourself (or another address) to activate voting power.
          </p>
          <div style={{ display: "flex", gap: "0.75rem" }}>
            <input
              placeholder={`Address (leave blank to self-delegate)`}
              value={delegatee}
              onChange={(e) => setDelegatee(e.target.value)}
              style={{ flex: 1 }}
            />
            <button
              className="btn-primary"
              disabled={delegatePending || delegateConfirming}
              onClick={handleDelegate}
            >
              {delegatePending || delegateConfirming ? (
                <><span className="spinner" style={{ width: 14, height: 14 }} /> Delegating…</>
              ) : (
                "Delegate"
              )}
            </button>
          </div>
        </div>
      )}

      {/* ── Recent Swaps (from Subgraph) ─────────────────────────────── */}
      <div className="card">
        <div className="flex-between" style={{ marginBottom: "0.75rem" }}>
          <div className="card-title" style={{ margin: 0 }}>Recent Swaps</div>
          <span className="text-sm text-muted">via The Graph</span>
        </div>
        {swapsError && (
          <p className="text-sm text-muted">
            Subgraph unavailable — configure URL in <code>src/config/subgraph.js</code>
          </p>
        )}
        {!swapsError && recentSwaps === null && <span className="spinner" />}
        {!swapsError && recentSwaps?.length === 0 && (
          <p className="text-sm text-muted">No swaps recorded yet.</p>
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
              {recentSwaps.map((s) => (
                <tr key={s.id}>
                  <td className="mono">{shortAddr(s.sender)}</td>
                  <td className="mono">
                    {s.amount0In !== "0" ? `${fmt(BigInt(s.amount0In))} T0` : `${fmt(BigInt(s.amount1In))} T1`}
                  </td>
                  <td className="mono">
                    {s.amount0Out !== "0" ? `${fmt(BigInt(s.amount0Out))} T0` : `${fmt(BigInt(s.amount1Out))} T1`}
                  </td>
                  <td className="text-muted text-sm">
                    {new Date(Number(s.timestamp) * 1000).toLocaleTimeString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
