import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits, parseUnits } from "viem";
import { ADDRESSES, AMM_ABI, VAULT_ABI } from "../config/contracts";
import { parseContractError } from "../hooks/useToast";

function fmt(val, decimals = 18, dp = 4) {
  if (val === undefined || val === null) return "—";
  try {
    const n = parseFloat(formatUnits(val, decimals));
    return n.toLocaleString(undefined, { maximumFractionDigits: dp });
  } catch {
    return "—";
  }
}

function Panel({ title, children }) {
  return (
    <div className="card section-gap">
      <div className="card-title" style={{ marginBottom: "1rem" }}>
        {title}
      </div>
      {children}
    </div>
  );
}

export default function Marketplace({ toast }) {
  const { address, isConnected } = useAccount();

  // ── Swap state ─────────────────────────────────────────────────────────────
  const [swapIn, setSwapIn] = useState("");
  const [swapDir, setSwapDir] = useState(0); // 0 = token0→token1, 1 = token1→token0

  // ── Deposit state ──────────────────────────────────────────────────────────
  const [depositAmt, setDepositAmt] = useState("");

  // ── Add Liquidity state ────────────────────────────────────────────────────
  const [liq0, setLiq0] = useState("");
  const [liq1, setLiq1] = useState("");

  // ── Reads ──────────────────────────────────────────────────────────────────
  const { data: reserves, refetch: refetchReserves } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "getReserves",
  });

  const { data: lpSupply } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "totalSupply",
  });

  const { data: vaultAssets, refetch: refetchVault } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "totalAssets",
  });

  const { data: vaultSupply } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "totalSupply",
  });

  const { data: userVaultShares, refetch: refetchShares } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address },
  });

  // Expected output for swap
  const swapInBig = (() => {
    try {
      return swapIn ? parseUnits(swapIn, 18) : 0n;
    } catch {
      return 0n;
    }
  })();

  const { data: amountOut } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "getAmountOut",
    args: reserves
      ? swapDir === 0
        ? [swapInBig, reserves[0], reserves[1]]
        : [swapInBig, reserves[1], reserves[0]]
      : [0n, 1n, 1n],
    query: { enabled: !!reserves && swapInBig > 0n },
  });

  // ── Swap write ─────────────────────────────────────────────────────────────
  const {
    writeContract: writeSwap,
    data: swapHash,
    isPending: swapPending,
    error: swapError,
  } = useWriteContract();

  const { isLoading: swapConfirming, isSuccess: swapSuccess } = useWaitForTransactionReceipt({
    hash: swapHash,
  });

  useEffect(() => {
    if (swapSuccess) {
      toast?.success("Swap confirmed!");
      setSwapIn("");
      refetchReserves();
    }
  }, [swapSuccess]);

  useEffect(() => {
    if (swapError) toast?.error(parseContractError(swapError));
  }, [swapError]);

  const handleSwap = () => {
    if (!swapIn || swapInBig === 0n) {
      toast?.error("Enter an amount");
      return;
    }
    if (!amountOut) {
      toast?.error("Unable to calculate output");
      return;
    }
    const slippage = (amountOut * 95n) / 100n; // 5% slippage
    writeSwap({
      address: ADDRESSES.AMM,
      abi: AMM_ABI,
      functionName: "swap",
      args: swapDir === 0 ? [0n, slippage, address, "0x"] : [slippage, 0n, address, "0x"],
    });
  };

  // ── Deposit write ──────────────────────────────────────────────────────────
  const {
    writeContract: writeDeposit,
    data: depositHash,
    isPending: depositPending,
    error: depositError,
  } = useWriteContract();

  const { isLoading: depositConfirming, isSuccess: depositSuccess } = useWaitForTransactionReceipt({
    hash: depositHash,
  });

  useEffect(() => {
    if (depositSuccess) {
      toast?.success("Deposit confirmed!");
      setDepositAmt("");
      refetchVault();
      refetchShares();
    }
  }, [depositSuccess]);

  useEffect(() => {
    if (depositError) toast?.error(parseContractError(depositError));
  }, [depositError]);

  const handleDeposit = () => {
    const amt = (() => {
      try {
        return parseUnits(depositAmt, 18);
      } catch {
        return 0n;
      }
    })();
    if (!depositAmt || amt === 0n) {
      toast?.error("Enter an amount");
      return;
    }
    writeDeposit({
      address: ADDRESSES.VAULT,
      abi: VAULT_ABI,
      functionName: "deposit",
      args: [amt, address],
    });
  };

  // ── Add Liquidity write ────────────────────────────────────────────────────
  const {
    writeContract: writeLiquidity,
    data: liqHash,
    isPending: liqPending,
    error: liqError,
  } = useWriteContract();

  const { isLoading: liqConfirming, isSuccess: liqSuccess } = useWaitForTransactionReceipt({
    hash: liqHash,
  });

  useEffect(() => {
    if (liqSuccess) {
      toast?.success("Liquidity added!");
      setLiq0("");
      setLiq1("");
      refetchReserves();
    }
  }, [liqSuccess]);

  useEffect(() => {
    if (liqError) toast?.error(parseContractError(liqError));
  }, [liqError]);

  const handleAddLiquidity = () => {
    const a0 = (() => {
      try {
        return parseUnits(liq0, 18);
      } catch {
        return 0n;
      }
    })();
    const a1 = (() => {
      try {
        return parseUnits(liq1, 18);
      } catch {
        return 0n;
      }
    })();
    if (!liq0 || !liq1 || a0 === 0n || a1 === 0n) {
      toast?.error("Enter both amounts");
      return;
    }
    writeLiquidity({
      address: ADDRESSES.AMM,
      abi: AMM_ABI,
      functionName: "addLiquidity",
      args: [a0, a1, (a0 * 95n) / 100n, (a1 * 95n) / 100n, address],
    });
  };

  const pricePerShare =
    vaultSupply && vaultAssets && vaultSupply > 0n
      ? Number(formatUnits(vaultAssets, 18)) / Number(formatUnits(vaultSupply, 18))
      : null;

  return (
    <div className="page">
      <h1 className="page-title">Marketplace</h1>

      {/* ── Pool Info ───────────────────────────────────────────────────── */}
      <div className="grid-2 section-gap">
        <div className="card">
          <div className="card-title">AMM Pool</div>
          <div className="stat-row">
            <span className="label">Reserve 0</span>
            <span className="value mono">{fmt(reserves?.[0])}</span>
          </div>
          <div className="stat-row">
            <span className="label">Reserve 1</span>
            <span className="value mono">{fmt(reserves?.[1])}</span>
          </div>
          <div className="stat-row">
            <span className="label">LP Supply</span>
            <span className="value mono">{fmt(lpSupply)}</span>
          </div>
          {reserves && reserves[0] > 0n && reserves[1] > 0n && (
            <div className="stat-row">
              <span className="label">Price T0/T1</span>
              <span className="value mono">
                {(
                  Number(formatUnits(reserves[1], 18)) / Number(formatUnits(reserves[0], 18))
                ).toFixed(4)}
              </span>
            </div>
          )}
        </div>

        <div className="card">
          <div className="card-title">ERC-4626 Vault</div>
          <div className="stat-row">
            <span className="label">Total Assets</span>
            <span className="value mono">{fmt(vaultAssets)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Total Shares</span>
            <span className="value mono">{fmt(vaultSupply)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Price / Share</span>
            <span className="value mono">
              {pricePerShare !== null ? pricePerShare.toFixed(6) : "—"}
            </span>
          </div>
          {isConnected && (
            <div className="stat-row">
              <span className="label">Your Shares</span>
              <span className="value mono">{fmt(userVaultShares)}</span>
            </div>
          )}
        </div>
      </div>

      {/* ── Swap ────────────────────────────────────────────────────────── */}
      <Panel title="Swap Tokens">
        {!isConnected ? (
          <p className="text-sm text-muted">Connect your wallet to swap.</p>
        ) : (
          <>
            <div style={{ display: "flex", gap: "0.75rem", marginBottom: "0.75rem" }}>
              <div style={{ flex: 1 }}>
                <label className="text-sm text-muted">Direction</label>
                <select
                  value={swapDir}
                  onChange={(e) => setSwapDir(Number(e.target.value))}
                  className="mt-1"
                >
                  <option value={0}>Token 0 → Token 1</option>
                  <option value={1}>Token 1 → Token 0</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label className="text-sm text-muted">Amount In</label>
                <input
                  className="mt-1"
                  type="number"
                  min="0"
                  placeholder="0.0"
                  value={swapIn}
                  onChange={(e) => setSwapIn(e.target.value)}
                />
              </div>
            </div>

            {amountOut !== undefined && swapIn && (
              <div className="card" style={{ background: "var(--bg3)", marginBottom: "0.75rem" }}>
                <div className="stat-row">
                  <span className="label">Expected output (after 0.3% fee)</span>
                  <span className="value mono">{fmt(amountOut)}</span>
                </div>
                <div className="stat-row">
                  <span className="label">Min received (5% slippage)</span>
                  <span className="value mono">{fmt((amountOut * 95n) / 100n)}</span>
                </div>
              </div>
            )}

            <button
              className="btn-primary"
              style={{ width: "100%" }}
              disabled={swapPending || swapConfirming || !swapIn}
              onClick={handleSwap}
            >
              {swapPending || swapConfirming ? (
                <>
                  <span className="spinner" style={{ width: 14, height: 14 }} />{" "}
                  {swapConfirming ? "Confirming…" : "Waiting…"}
                </>
              ) : (
                "Swap"
              )}
            </button>
          </>
        )}
      </Panel>

      {/* ── Deposit into Vault ──────────────────────────────────────────── */}
      <Panel title="Deposit into Vault (ERC-4626)">
        {!isConnected ? (
          <p className="text-sm text-muted">Connect your wallet to deposit.</p>
        ) : (
          <>
            <p className="text-sm text-muted" style={{ marginBottom: "0.75rem" }}>
              Deposit assets to receive vault shares (vGFI). Shares appreciate as the vault earns
              yield.
            </p>
            <div style={{ display: "flex", gap: "0.75rem" }}>
              <input
                type="number"
                min="0"
                placeholder="Amount to deposit"
                value={depositAmt}
                onChange={(e) => setDepositAmt(e.target.value)}
                style={{ flex: 1 }}
              />
              <button
                className="btn-primary"
                disabled={depositPending || depositConfirming || !depositAmt}
                onClick={handleDeposit}
              >
                {depositPending || depositConfirming ? (
                  <>
                    <span className="spinner" style={{ width: 14, height: 14 }} />{" "}
                    {depositConfirming ? "Confirming…" : "Waiting…"}
                  </>
                ) : (
                  "Deposit"
                )}
              </button>
            </div>
          </>
        )}
      </Panel>

      {/* ── Add Liquidity ───────────────────────────────────────────────── */}
      <Panel title="Add Liquidity">
        {!isConnected ? (
          <p className="text-sm text-muted">Connect your wallet to add liquidity.</p>
        ) : (
          <>
            <div style={{ display: "flex", gap: "0.75rem", marginBottom: "0.75rem" }}>
              <input
                type="number"
                min="0"
                placeholder="Amount Token 0"
                value={liq0}
                onChange={(e) => setLiq0(e.target.value)}
              />
              <input
                type="number"
                min="0"
                placeholder="Amount Token 1"
                value={liq1}
                onChange={(e) => setLiq1(e.target.value)}
              />
            </div>
            <button
              className="btn-primary"
              style={{ width: "100%" }}
              disabled={liqPending || liqConfirming || !liq0 || !liq1}
              onClick={handleAddLiquidity}
            >
              {liqPending || liqConfirming ? (
                <>
                  <span className="spinner" style={{ width: 14, height: 14 }} />{" "}
                  {liqConfirming ? "Confirming…" : "Waiting…"}
                </>
              ) : (
                "Add Liquidity"
              )}
            </button>
          </>
        )}
      </Panel>
    </div>
  );
}
