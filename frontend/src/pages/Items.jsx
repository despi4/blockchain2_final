import { useState, useEffect } from "react";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { formatUnits, parseEther } from "viem";
import { ADDRESSES, ITEM_IDS, ERC1155_ABI, CRAFTING_ABI, LOOT_ABI } from "../config/contracts";
import { parseContractError } from "../hooks/useToast";

const ITEM_IDS_LIST = Object.keys(ITEM_IDS).map(Number);

function ItemCard({ id, balance, selected, onSelect }) {
  const meta = ITEM_IDS[id];
  return (
    <div
      onClick={() => onSelect?.(id)}
      style={{
        background: selected ? "rgba(124,58,237,0.2)" : "var(--bg2)",
        border: `1px solid ${selected ? "var(--accent2)" : "var(--border)"}`,
        borderRadius: "var(--radius)",
        padding: "1rem",
        cursor: onSelect ? "pointer" : "default",
        textAlign: "center",
        transition: "border-color 0.15s, background 0.15s",
      }}
    >
      <div style={{ fontSize: "2rem" }}>{meta.emoji}</div>
      <div style={{ fontWeight: 700, fontSize: "0.9rem", marginTop: "0.25rem" }}>{meta.name}</div>
      <div style={{ fontSize: "0.75rem", color: "var(--text2)", marginTop: "0.15rem" }}>
        {meta.type}
      </div>
      <div
        style={{
          marginTop: "0.5rem",
          fontSize: "1.1rem",
          fontWeight: 800,
          fontFamily: "monospace",
          color: balance > 0 ? "var(--accent2)" : "var(--text2)",
        }}
      >
        ×{balance?.toString() ?? "—"}
      </div>
    </div>
  );
}

export default function Items({ toast }) {
  const { address, isConnected } = useAccount();

  const [selectedCraft, setSelectedCraft] = useState(null); // outputId to craft
  const [lootFee, setLootFee] = useState(null);
  const [pendingLoot, setPendingLoot] = useState(null);

  // ── Batch read all item balances ──────────────────────────────────────────
  const balanceCalls = ITEM_IDS_LIST.map((id) => ({
    address: ADDRESSES.ITEM_NFT,
    abi: ERC1155_ABI,
    functionName: "balanceOf",
    args: [address ?? "0x0000000000000000000000000000000000000000", BigInt(id)],
  }));

  const { data: balances, refetch: refetchBalances } = useReadContracts({
    contracts: balanceCalls,
    query: { enabled: !!address },
  });

  // ── Loot fee & pending loot ────────────────────────────────────────────────
  const { data: lootFeeRaw } = useReadContract({
    address: ADDRESSES.LOOT,
    abi: LOOT_ABI,
    functionName: "lootFee",
  });

  const { data: pendingLootRaw } = useReadContract({
    address: ADDRESSES.LOOT,
    abi: LOOT_ABI,
    functionName: "pendingLoot",
    args: [address],
    query: { enabled: !!address },
  });

  // ── Drop rate (governance-controlled) ────────────────────────────────────
  const { data: dropRate } = useReadContract({
    address: ADDRESSES.LOOT,
    abi: LOOT_ABI,
    functionName: "dropRate",
  });

  // ── VRF Loot drop ────────────────────────────────────────────────────────
  const {
    writeContract: writeLoot,
    data: lootTxHash,
    isPending: lootPending,
    error: lootError,
  } = useWriteContract();

  const { isLoading: lootConfirming, isSuccess: lootSuccess } = useWaitForTransactionReceipt({
    hash: lootTxHash,
  });

  useEffect(() => {
    if (lootSuccess) {
      toast?.success("Loot drop requested! Waiting for VRF…");
      refetchBalances();
    }
  }, [lootSuccess]);

  useEffect(() => {
    if (lootError) toast?.error(parseContractError(lootError));
  }, [lootError]);

  const handleRequestLoot = () => {
    const fee = lootFeeRaw ?? parseEther("0.001");
    writeLoot({
      address: ADDRESSES.LOOT,
      abi: LOOT_ABI,
      functionName: "requestLootDrop",
      value: fee,
    });
  };

  // ── Crafting ──────────────────────────────────────────────────────────────
  const craftMeta = selectedCraft ? ITEM_IDS[selectedCraft] : null;

  const { data: craftingCost } = useReadContract({
    address: ADDRESSES.CRAFTING,
    abi: CRAFTING_ABI,
    functionName: "getCraftingCost",
    args: [BigInt(selectedCraft ?? 5)],
    query: { enabled: !!selectedCraft },
  });

  const {
    writeContract: writeCraft,
    data: craftTxHash,
    isPending: craftPending,
    error: craftError,
  } = useWriteContract();

  const { isLoading: craftConfirming, isSuccess: craftSuccess } = useWaitForTransactionReceipt({
    hash: craftTxHash,
  });

  useEffect(() => {
    if (craftSuccess) {
      toast?.success(`${craftMeta?.name} crafted!`);
      refetchBalances();
      setSelectedCraft(null);
    }
  }, [craftSuccess]);

  useEffect(() => {
    if (craftError) toast?.error(parseContractError(craftError));
  }, [craftError]);

  const handleCraft = () => {
    if (!selectedCraft || !craftingCost) return;
    writeCraft({
      address: ADDRESSES.CRAFTING,
      abi: CRAFTING_ABI,
      functionName: "craft",
      args: [craftingCost[0], craftingCost[1], BigInt(selectedCraft)],
    });
  };

  const getBalance = (id) => {
    if (!balances) return undefined;
    const idx = ITEM_IDS_LIST.indexOf(id);
    return balances[idx]?.result;
  };

  const craftableItems = ITEM_IDS_LIST.filter((id) => ITEM_IDS[id].recipe);
  const resourceItems = ITEM_IDS_LIST.filter((id) => ITEM_IDS[id].type === "resource");

  return (
    <div className="page">
      <h1 className="page-title">Items & Crafting</h1>

      {/* ── Game Parameters (DAO-governed) ─────────────────────────────── */}
      <div className="card section-gap">
        <div className="card-title">Game Parameters (DAO-Governed)</div>
        <div className="grid-2 mt-1">
          <div className="stat-row">
            <span className="label">Drop Rate</span>
            <span className="value mono">{dropRate?.toString() ?? "—"} / 1000</span>
          </div>
          <div className="stat-row">
            <span className="label">Loot Fee</span>
            <span className="value mono">
              {lootFeeRaw !== undefined ? `${formatUnits(lootFeeRaw, 18)} ETH` : "—"}
            </span>
          </div>
        </div>
        <p className="text-sm text-muted mt-1">
          Drop rates and crafting costs are controlled by DAO governance. Vote on proposals in the{" "}
          <a href="/governance">Governance</a> tab to change them.
        </p>
      </div>

      {/* ── VRF Loot Drop ──────────────────────────────────────────────── */}
      <div className="card section-gap">
        <div className="card-title">Loot Drop (Chainlink VRF)</div>
        <p className="text-sm text-muted mt-1" style={{ marginBottom: "0.75rem" }}>
          Pay a small fee to trigger a provably random loot drop powered by Chainlink VRF. You will
          receive random in-game items based on the current drop rate.
        </p>
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to request a loot drop.</p>
        ) : (
          <div style={{ display: "flex", gap: "1rem", alignItems: "center", flexWrap: "wrap" }}>
            <button
              className="btn-primary"
              disabled={lootPending || lootConfirming}
              onClick={handleRequestLoot}
            >
              {lootPending || lootConfirming ? (
                <>
                  <span className="spinner" style={{ width: 14, height: 14 }} />{" "}
                  {lootConfirming ? "Waiting for VRF…" : "Requesting…"}
                </>
              ) : (
                `Request Loot Drop (${lootFeeRaw !== undefined ? formatUnits(lootFeeRaw, 18) : "0.001"} ETH)`
              )}
            </button>
            {pendingLootRaw && !pendingLootRaw[1] && (
              <span className="badge" style={{ background: "#f59e0b22", color: "#f59e0b" }}>
                VRF pending…
              </span>
            )}
          </div>
        )}
      </div>

      {/* ── Item Inventory ──────────────────────────────────────────────── */}
      <div className="section-gap">
        <div className="flex-between" style={{ marginBottom: "0.75rem" }}>
          <h2 style={{ fontSize: "1rem", fontWeight: 700 }}>Your Inventory (ERC-1155)</h2>
          {!isConnected && <span className="text-sm text-muted">Connect wallet to view</span>}
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(130px, 1fr))",
            gap: "0.75rem",
          }}
        >
          {ITEM_IDS_LIST.map((id) => (
            <ItemCard
              key={id}
              id={id}
              balance={isConnected ? Number(getBalance(id) ?? 0) : undefined}
            />
          ))}
        </div>
      </div>

      {/* ── Crafting ────────────────────────────────────────────────────── */}
      <div className="card section-gap">
        <div className="card-title" style={{ marginBottom: "0.75rem" }}>
          Crafting
        </div>

        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to craft items.</p>
        ) : (
          <>
            <p className="text-sm text-muted" style={{ marginBottom: "0.75rem" }}>
              Select an item to craft. Resources will be consumed from your inventory.
            </p>

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fill, minmax(130px, 1fr))",
                gap: "0.75rem",
                marginBottom: "1rem",
              }}
            >
              {craftableItems.map((id) => (
                <ItemCard
                  key={id}
                  id={id}
                  balance={Number(getBalance(id) ?? 0)}
                  selected={selectedCraft === id}
                  onSelect={setSelectedCraft}
                />
              ))}
            </div>

            {selectedCraft && (
              <div className="card" style={{ background: "var(--bg3)", marginBottom: "0.75rem" }}>
                <div className="card-title">
                  Recipe: {craftMeta?.emoji} {craftMeta?.name}
                </div>
                {craftingCost ? (
                  <div className="mt-1">
                    {craftingCost[0].map((inputId, i) => {
                      const mat = ITEM_IDS[Number(inputId)];
                      const have = Number(getBalance(Number(inputId)) ?? 0);
                      const need = Number(craftingCost[1][i]);
                      return (
                        <div key={i} className="stat-row">
                          <span className="label">
                            {mat?.emoji} {mat?.name}
                          </span>
                          <span
                            className="value mono"
                            style={{ color: have >= need ? "var(--success)" : "var(--danger)" }}
                          >
                            {have} / {need}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <span className="spinner" style={{ marginTop: "0.5rem" }} />
                )}

                <button
                  className="btn-primary"
                  style={{ width: "100%", marginTop: "0.75rem" }}
                  disabled={craftPending || craftConfirming || !craftingCost}
                  onClick={handleCraft}
                >
                  {craftPending || craftConfirming ? (
                    <>
                      <span className="spinner" style={{ width: 14, height: 14 }} />{" "}
                      {craftConfirming ? "Confirming…" : "Crafting…"}
                    </>
                  ) : (
                    `Craft ${craftMeta?.name}`
                  )}
                </button>
              </div>
            )}
          </>
        )}
      </div>

      {/* ── Resources reference ──────────────────────────────────────────── */}
      <div className="card">
        <div className="card-title" style={{ marginBottom: "0.75rem" }}>
          Resource Guide
        </div>
        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Type</th>
              <th>How to get</th>
            </tr>
          </thead>
          <tbody>
            {ITEM_IDS_LIST.map((id) => {
              const meta = ITEM_IDS[id];
              return (
                <tr key={id}>
                  <td>
                    {meta.emoji} {meta.name}
                  </td>
                  <td>
                    <span
                      className="badge"
                      style={{ background: "var(--bg3)", color: "var(--text2)" }}
                    >
                      {meta.type}
                    </span>
                  </td>
                  <td className="text-muted text-sm">
                    {meta.type === "resource" ? "Loot drops" : `Craft from resources`}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
