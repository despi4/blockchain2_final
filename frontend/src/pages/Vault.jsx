import { useEffect, useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { ADDRESSES, ERC20_ABI, VAULT_ABI, isConfiguredAddress } from "../config/contracts";
import ConfigNotice from "../components/ConfigNotice";
import { parseContractError } from "../hooks/useToast";
import { formatToken, parseTokenInput, shortAddress } from "../utils/format";

const MAX_UINT256 = 2n ** 256n - 1n;

export default function Vault({ toast }) {
  const { address, isConnected } = useAccount();
  const [depositAmount, setDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [redeemShares, setRedeemShares] = useState("");

  const configured = isConfiguredAddress(ADDRESSES.VAULT);

  const { data: assetAddress } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "asset",
    query: { enabled: configured },
  });

  const { data: assetSymbol } = useReadContract({
    address: assetAddress,
    abi: ERC20_ABI,
    functionName: "symbol",
    query: { enabled: isConfiguredAddress(assetAddress) },
  });

  const { data: assetBalance } = useReadContract({
    address: assetAddress,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && isConfiguredAddress(assetAddress) },
  });

  const { data: allowance } = useReadContract({
    address: assetAddress,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address, ADDRESSES.VAULT],
    query: { enabled: !!address && isConfiguredAddress(assetAddress) && configured },
  });

  const { data: totalAssets, refetch: refetchAssets } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "totalAssets",
    query: { enabled: configured },
  });

  const { data: totalSupply } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "totalSupply",
    query: { enabled: configured },
  });

  const { data: shareBalance, refetch: refetchShares } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && configured },
  });

  const { data: maxWithdraw } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "maxWithdraw",
    args: [address],
    query: { enabled: !!address && configured },
  });

  const { data: previewDeposit } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "previewDeposit",
    args: [parseTokenInput(depositAmount)],
    query: { enabled: configured && parseTokenInput(depositAmount) > 0n },
  });

  const { data: previewWithdraw } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "previewWithdraw",
    args: [parseTokenInput(withdrawAmount)],
    query: { enabled: configured && parseTokenInput(withdrawAmount) > 0n },
  });

  const { data: previewRedeem } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "previewRedeem",
    args: [parseTokenInput(redeemShares)],
    query: { enabled: configured && parseTokenInput(redeemShares) > 0n },
  });

  const { data: accruedFees } = useReadContract({
    address: ADDRESSES.VAULT,
    abi: VAULT_ABI,
    functionName: "accruedFees",
    query: { enabled: configured },
  });

  const depositAmountWei = parseTokenInput(depositAmount);
  const needsApproval = depositAmountWei > 0n && (allowance || 0n) < depositAmountWei;

  const { writeContract, data: txHash, isPending, error } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) {
      toast?.success("Vault transaction confirmed.");
      refetchAssets();
      refetchShares();
    }
  }, [isSuccess, refetchAssets, refetchShares, toast]);

  useEffect(() => {
    if (error) toast?.error(parseContractError(error));
  }, [error, toast]);

  return (
    <div className="page">
      <h1 className="page-title">Vault</h1>

      <ConfigNotice
        title="Frontend contract config"
        lines={!configured ? ["Set VITE_VAULT_ADDRESS and VITE_GOLD_TOKEN_ADDRESS."] : []}
      />

      <div className="grid-2 section-gap">
        <div className="card">
          <div className="card-title">Vault state</div>
          <div className="stat-row">
            <span className="label">Vault</span>
            <span className="value mono">{shortAddress(ADDRESSES.VAULT)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Asset</span>
            <span className="value mono">{shortAddress(assetAddress)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Total assets</span>
            <span className="value">{formatToken(totalAssets)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Total shares</span>
            <span className="value">{formatToken(totalSupply)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Accrued fees</span>
            <span className="value">{formatToken(accruedFees)}</span>
          </div>
        </div>

        <div className="card">
          <div className="card-title">Your position</div>
          <div className="stat-row">
            <span className="label">{assetSymbol || "Asset"} balance</span>
            <span className="value">
              {isConnected ? formatToken(assetBalance) : "Connect wallet"}
            </span>
          </div>
          <div className="stat-row">
            <span className="label">Vault shares</span>
            <span className="value">
              {isConnected ? formatToken(shareBalance) : "Connect wallet"}
            </span>
          </div>
          <div className="stat-row">
            <span className="label">Max withdraw</span>
            <span className="value">
              {isConnected ? formatToken(maxWithdraw) : "Connect wallet"}
            </span>
          </div>
        </div>
      </div>

      <div className="card section-gap">
        <div className="card-title">Deposit</div>
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to deposit.</p>
        ) : (
          <>
            <input
              type="number"
              min="0"
              value={depositAmount}
              onChange={(event) => setDepositAmount(event.target.value)}
              placeholder={`Deposit ${assetSymbol || "asset"}`}
              style={{ maxWidth: "260px", marginBottom: "0.75rem" }}
            />
            <div className="stat-row" style={{ marginBottom: "0.75rem" }}>
              <span className="label">Preview shares</span>
              <span className="value">{formatToken(previewDeposit)}</span>
            </div>
            {needsApproval && (
              <button
                className="btn-secondary"
                onClick={() =>
                  writeContract({
                    address: assetAddress,
                    abi: ERC20_ABI,
                    functionName: "approve",
                    args: [ADDRESSES.VAULT, MAX_UINT256],
                  })
                }
                style={{ marginRight: "0.75rem" }}
              >
                Approve {assetSymbol || "asset"}
              </button>
            )}
            <button
              className="btn-primary"
              disabled={isPending || confirming}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.VAULT,
                  abi: VAULT_ABI,
                  functionName: "deposit",
                  args: [depositAmountWei, address],
                })
              }
            >
              {isPending || confirming ? "Submitting..." : "Deposit"}
            </button>
          </>
        )}
      </div>

      <div className="card section-gap">
        <div className="card-title">Withdraw</div>
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to withdraw.</p>
        ) : (
          <>
            <input
              type="number"
              min="0"
              value={withdrawAmount}
              onChange={(event) => setWithdrawAmount(event.target.value)}
              placeholder="Withdraw assets"
              style={{ maxWidth: "260px", marginBottom: "0.75rem" }}
            />
            <div className="stat-row" style={{ marginBottom: "0.75rem" }}>
              <span className="label">Shares burned</span>
              <span className="value">{formatToken(previewWithdraw)}</span>
            </div>
            <button
              className="btn-primary"
              disabled={isPending || confirming}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.VAULT,
                  abi: VAULT_ABI,
                  functionName: "withdraw",
                  args: [parseTokenInput(withdrawAmount), address, address],
                })
              }
            >
              {isPending || confirming ? "Submitting..." : "Withdraw assets"}
            </button>
          </>
        )}
      </div>

      <div className="card">
        <div className="card-title">Redeem shares</div>
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to redeem.</p>
        ) : (
          <>
            <input
              type="number"
              min="0"
              value={redeemShares}
              onChange={(event) => setRedeemShares(event.target.value)}
              placeholder="Redeem shares"
              style={{ maxWidth: "260px", marginBottom: "0.75rem" }}
            />
            <div className="stat-row" style={{ marginBottom: "0.75rem" }}>
              <span className="label">Preview assets</span>
              <span className="value">{formatToken(previewRedeem)}</span>
            </div>
            <button
              className="btn-primary"
              disabled={isPending || confirming}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.VAULT,
                  abi: VAULT_ABI,
                  functionName: "redeem",
                  args: [parseTokenInput(redeemShares), address, address],
                })
              }
            >
              {isPending || confirming ? "Submitting..." : "Redeem shares"}
            </button>
          </>
        )}
      </div>
    </div>
  );
}
