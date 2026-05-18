import { useEffect, useState } from "react";
import { useAccount, useReadContract, useWaitForTransactionReceipt } from "wagmi";
import { useWriteContract } from "../hooks/useWrite";
import {
  ADDRESSES,
  ERC20_ABI,
  ITEM_METADATA,
  LOOT_ABI,
  isConfiguredAddress,
} from "../config/contracts";
import ConfigNotice from "../components/ConfigNotice";
import { fetchRecentLootDrops } from "../config/subgraph";
import { useTransactionToast } from "../hooks/useTransactionToast";
import { basisPointsToPercent, formatToken, shortAddress, timestampToLocal } from "../utils/format";

const MAX_UINT256 = 2n ** 256n - 1n;

export default function Loot({ toast }) {
  const { address, isConnected } = useAccount();
  const [lootHistory, setLootHistory] = useState(null);
  const [historyError, setHistoryError] = useState(false);

  const configured = {
    loot: isConfiguredAddress(ADDRESSES.LOOT),
    gold: isConfiguredAddress(ADDRESSES.GOLD_TOKEN),
  };

  const { data: goldBalance } = useReadContract({
    address: ADDRESSES.GOLD_TOKEN,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && configured.gold },
  });

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: ADDRESSES.GOLD_TOKEN,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address, ADDRESSES.LOOT],
    query: { enabled: !!address && configured.gold && configured.loot },
  });

  const { data: lootFee } = useReadContract({
    address: ADDRESSES.LOOT,
    abi: LOOT_ABI,
    functionName: "lootFee",
    query: { enabled: configured.loot },
  });

  const { data: dropRates } = useReadContract({
    address: ADDRESSES.LOOT,
    abi: LOOT_ABI,
    functionName: "getDropRates",
    query: { enabled: configured.loot },
  });

  const { writeContract, data: txHash, isPending, error } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useTransactionToast(toast, isSuccess, error, "Loot request submitted.");

  useEffect(() => {
    if (isSuccess) refetchAllowance();
  }, [isSuccess, refetchAllowance]);

  useEffect(() => {
    fetchRecentLootDrops(10)
      .then((data) => setLootHistory(data?.lootDrops ?? []))
      .catch(() => {
        setHistoryError(true);
        setLootHistory([]);
      });
  }, []);

  const needsApproval = (lootFee || 0n) > 0n && (allowance || 0n) < (lootFee || 0n);

  return (
    <div className="page">
      <h1 className="page-title">Loot Drop</h1>

      <ConfigNotice
        title="Frontend contract config"
        lines={[
          ...(!configured.loot ? ["Set VITE_LOOT_ADDRESS."] : []),
          ...(!configured.gold ? ["Set VITE_GOLD_TOKEN_ADDRESS."] : []),
        ]}
      />

      <div className="grid-2 section-gap">
        <div className="card">
          <div className="card-title">Loot settings</div>
          <div className="stat-row">
            <span className="label">Loot contract</span>
            <span className="value mono">{shortAddress(ADDRESSES.LOOT)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Fee</span>
            <span className="value">{formatToken(lootFee)} GOLD</span>
          </div>
          <div className="stat-row">
            <span className="label">Your GOLD</span>
            <span className="value">
              {isConnected ? formatToken(goldBalance) : "Connect wallet"}
            </span>
          </div>
        </div>

        <div className="card">
          <div className="card-title">Drop rates</div>
          {!dropRates && <p className="text-sm text-muted">No drop table loaded.</p>}
          {dropRates &&
            dropRates[0].map((itemId, index) => (
              <div key={`${itemId}-${index}`} className="stat-row">
                <span className="label">
                  {ITEM_METADATA[Number(itemId)]?.name || `Item ${itemId}`}
                </span>
                <span className="value">{basisPointsToPercent(dropRates[1][index])}</span>
              </div>
            ))}
        </div>
      </div>

      <div className="card section-gap">
        <div className="card-title">Request randomness-backed loot</div>
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to request loot.</p>
        ) : (
          <>
            <p className="text-sm text-muted" style={{ marginBottom: "0.75rem" }}>
              The contract charges GOLD, requests randomness from the configured coordinator, and
              mints ERC1155 rewards after fulfillment.
            </p>
            {needsApproval && (
              <button
                className="btn-secondary"
                onClick={() =>
                  writeContract({
                    address: ADDRESSES.GOLD_TOKEN,
                    abi: ERC20_ABI,
                    functionName: "approve",
                    args: [ADDRESSES.LOOT, MAX_UINT256],
                  })
                }
                style={{ marginRight: "0.75rem" }}
              >
                Approve GOLD
              </button>
            )}
            <button
              className="btn-primary"
              disabled={isPending || confirming || needsApproval}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.LOOT,
                  abi: LOOT_ABI,
                  functionName: "requestLootDrop",
                })
              }
            >
              {isPending || confirming ? "Submitting..." : "Request loot drop"}
            </button>
          </>
        )}
      </div>

      <div className="card">
        <div className="flex-between" style={{ marginBottom: "0.75rem" }}>
          <div className="card-title" style={{ margin: 0 }}>
            Indexed loot history
          </div>
          <span className="text-sm text-muted">via The Graph</span>
        </div>
        {historyError && (
          <p className="text-sm text-muted">
            Subgraph unavailable. Set VITE_SUBGRAPH_URL to view indexed loot.
          </p>
        )}
        {!historyError && lootHistory === null && <span className="spinner" />}
        {!historyError && lootHistory?.length === 0 && (
          <p className="text-sm text-muted">No indexed loot drops yet.</p>
        )}
        {!historyError && lootHistory?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Requester</th>
                <th>Request ID</th>
                <th>Reward</th>
                <th>Status</th>
                <th>Requested</th>
              </tr>
            </thead>
            <tbody>
              {lootHistory.map((entry) => (
                <tr key={entry.id}>
                  <td className="mono">{shortAddress(entry.requester)}</td>
                  <td className="mono">{entry.requestId}</td>
                  <td className="mono">
                    {entry.itemGranted
                      ? ITEM_METADATA[Number(entry.itemGranted)]?.name ||
                        `Item ${entry.itemGranted}`
                      : "--"}
                  </td>
                  <td>{entry.fulfilled ? "Fulfilled" : "Pending"}</td>
                  <td className="text-sm text-muted">{timestampToLocal(entry.requestedAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
