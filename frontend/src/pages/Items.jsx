import { useEffect, useState } from "react";
import { useAccount, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import {
  ADDRESSES,
  CRAFTING_ABI,
  DEFAULT_RECIPE_IDS,
  GAME_ITEMS_ABI,
  ITEM_IDS,
  ITEM_METADATA,
  isConfiguredAddress,
} from "../config/contracts";
import ConfigNotice from "../components/ConfigNotice";
import { parseContractError } from "../hooks/useToast";

function itemLabel(itemId) {
  const meta = ITEM_METADATA[itemId];
  if (!meta) return `Item ${itemId}`;
  return `${meta.emoji} ${meta.name}`;
}

function InventoryCard({ itemId, balance }) {
  const meta = ITEM_METADATA[itemId];

  return (
    <div className="card" style={{ padding: "1rem", textAlign: "center" }}>
      <div style={{ fontWeight: 800, fontSize: "1rem" }}>{meta?.emoji || "?"}</div>
      <div style={{ fontWeight: 700, marginTop: "0.35rem" }}>{meta?.name || `Item ${itemId}`}</div>
      <div className="text-sm text-muted">{meta?.type || "unknown"}</div>
      <div className="mt-1 mono" style={{ fontSize: "1.1rem", color: "var(--accent2)" }}>
        x{balance?.toString() ?? "--"}
      </div>
    </div>
  );
}

export default function Items({ toast }) {
  const { address, isConnected } = useAccount();
  const [selectedRecipeId, setSelectedRecipeId] = useState(DEFAULT_RECIPE_IDS[0]);
  const [craftAmount, setCraftAmount] = useState("1");

  const configured = {
    items: isConfiguredAddress(ADDRESSES.GAME_ITEMS),
    crafting: isConfiguredAddress(ADDRESSES.CRAFTING),
  };

  const { data: balances } = useReadContract({
    address: ADDRESSES.GAME_ITEMS,
    abi: GAME_ITEMS_ABI,
    functionName: "balanceOfBatch",
    args: [ITEM_IDS.map(() => address || ADDRESSES.GAME_ITEMS), ITEM_IDS.map((id) => BigInt(id))],
    query: { enabled: !!address && configured.items },
  });

  const recipeContracts = DEFAULT_RECIPE_IDS.map((recipeId) => ({
    address: ADDRESSES.CRAFTING,
    abi: CRAFTING_ABI,
    functionName: "getRecipe",
    args: [BigInt(recipeId)],
  }));

  const { data: recipeResults, refetch: refetchRecipes } = useReadContracts({
    contracts: recipeContracts,
    query: { enabled: configured.crafting },
  });

  const activeRecipes = !recipeResults
    ? []
    : recipeResults
        .map((result, index) => {
          const recipeId = DEFAULT_RECIPE_IDS[index];
          const recipe = result?.result;
          if (!recipe) return null;

          const [inputIds, inputAmounts, outputItemId, outputAmount, active] = recipe;
          return {
            recipeId,
            inputIds,
            inputAmounts,
            outputItemId: Number(outputItemId),
            outputAmount,
            active,
          };
        })
        .filter((recipe) => recipe && recipe.active && recipe.outputItemId !== 0);

  const selectedRecipe = activeRecipes.find((recipe) => recipe.recipeId === selectedRecipeId) || activeRecipes[0];

  useEffect(() => {
    if (selectedRecipe && selectedRecipe.recipeId !== selectedRecipeId) {
      setSelectedRecipeId(selectedRecipe.recipeId);
    }
  }, [selectedRecipe, selectedRecipeId]);

  const {
    writeContract,
    data: craftHash,
    isPending: craftPending,
    error: craftError,
  } = useWriteContract();

  const { isLoading: craftConfirming, isSuccess: craftSuccess } = useWaitForTransactionReceipt({
    hash: craftHash,
  });

  useEffect(() => {
    if (craftSuccess) {
      toast?.success("Crafting confirmed.");
      setCraftAmount("1");
      refetchRecipes();
    }
  }, [craftSuccess, refetchRecipes, toast]);

  useEffect(() => {
    if (craftError) toast?.error(parseContractError(craftError));
  }, [craftError, toast]);

  const handleCraft = () => {
    if (!selectedRecipe) {
      toast?.error("No active recipe found.");
      return;
    }

    const amount = BigInt(craftAmount || "0");
    if (amount === 0n) {
      toast?.error("Craft amount must be greater than zero.");
      return;
    }

    writeContract({
      address: ADDRESSES.CRAFTING,
      abi: CRAFTING_ABI,
      functionName: "craft",
      args: [BigInt(selectedRecipe.recipeId), amount],
    });
  };

  const missingConfig = [];
  if (!configured.items) missingConfig.push("Set VITE_GAME_ITEMS_ADDRESS.");
  if (!configured.crafting) missingConfig.push("Set VITE_CRAFTING_ADDRESS.");

  return (
    <div className="page">
      <h1 className="page-title">Crafting</h1>

      <ConfigNotice title="Frontend contract config" lines={missingConfig} />

      <div className="card section-gap">
        <div className="card-title">Inventory</div>
        {!isConnected && <p className="text-sm text-muted">Connect wallet to load ERC1155 balances.</p>}
        {isConnected && (
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))",
              gap: "0.75rem",
              marginTop: "0.75rem",
            }}
          >
            {ITEM_IDS.map((itemId, index) => (
              <InventoryCard key={itemId} itemId={itemId} balance={balances?.[index]} />
            ))}
          </div>
        )}
      </div>

      <div className="card section-gap">
        <div className="card-title">Recipes</div>
        {activeRecipes.length === 0 && (
          <p className="text-sm text-muted">
            No active recipes found. Create recipes onchain first, then refresh this page.
          </p>
        )}

        {activeRecipes.length > 0 && (
          <>
            <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap", marginBottom: "1rem" }}>
              <select
                value={selectedRecipeId}
                onChange={(event) => setSelectedRecipeId(Number(event.target.value))}
                style={{ maxWidth: "220px" }}
              >
                {activeRecipes.map((recipe) => (
                  <option key={recipe.recipeId} value={recipe.recipeId}>
                    {`Recipe #${recipe.recipeId} -> ${itemLabel(recipe.outputItemId)}`}
                  </option>
                ))}
              </select>

              <input
                type="number"
                min="1"
                value={craftAmount}
                onChange={(event) => setCraftAmount(event.target.value)}
                placeholder="Craft amount"
                style={{ maxWidth: "180px" }}
              />

              <button
                className="btn-primary"
                disabled={!isConnected || craftPending || craftConfirming}
                onClick={handleCraft}
              >
                {craftPending || craftConfirming ? "Crafting..." : "Craft"}
              </button>
            </div>

            {selectedRecipe && (
              <div className="card" style={{ background: "var(--bg3)" }}>
                <div className="card-title">Selected recipe</div>
                <div className="stat-row">
                  <span className="label">Output</span>
                  <span className="value">
                    {itemLabel(selectedRecipe.outputItemId)} x{selectedRecipe.outputAmount.toString()}
                  </span>
                </div>
                {selectedRecipe.inputIds.map((itemId, index) => (
                  <div key={`${selectedRecipe.recipeId}-${index}`} className="stat-row">
                    <span className="label">{itemLabel(Number(itemId))}</span>
                    <span className="value mono">
                      {selectedRecipe.inputAmounts[index].toString()} required
                    </span>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>

      <div className="card">
        <div className="card-title">Crafting notes</div>
        <p className="text-sm text-muted">
          This page is wired to the real `CraftingSystem` ABI. Recipes are loaded from onchain
          `getRecipe(recipeId)` calls instead of hardcoded frontend assumptions.
        </p>
      </div>
    </div>
  );
}
