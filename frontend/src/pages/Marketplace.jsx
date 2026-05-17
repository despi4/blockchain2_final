import { useEffect, useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import {
  ADDRESSES,
  AMM_ABI,
  ERC20_ABI,
  LP_TOKEN_ABI,
  isConfiguredAddress,
} from "../config/contracts";
import ConfigNotice from "../components/ConfigNotice";
import { parseContractError } from "../hooks/useToast";
import { formatToken, parseTokenInput, shortAddress } from "../utils/format";

const MAX_UINT256 = 2n ** 256n - 1n;

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
  const [swapDirection, setSwapDirection] = useState("0to1");
  const [swapAmount, setSwapAmount] = useState("");
  const [liquidity0, setLiquidity0] = useState("");
  const [liquidity1, setLiquidity1] = useState("");
  const [removeLpAmount, setRemoveLpAmount] = useState("");

  const configured = isConfiguredAddress(ADDRESSES.AMM);

  const { data: token0Address } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "token0",
    query: { enabled: configured },
  });

  const { data: token1Address } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "token1",
    query: { enabled: configured },
  });

  const { data: lpTokenAddress } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "lpToken",
    query: { enabled: configured },
  });

  const { data: reserves, refetch: refetchReserves } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "getReserves",
    query: { enabled: configured },
  });

  const { data: token0Symbol } = useReadContract({
    address: token0Address,
    abi: ERC20_ABI,
    functionName: "symbol",
    query: { enabled: isConfiguredAddress(token0Address) },
  });

  const { data: token1Symbol } = useReadContract({
    address: token1Address,
    abi: ERC20_ABI,
    functionName: "symbol",
    query: { enabled: isConfiguredAddress(token1Address) },
  });

  const { data: token0Balance } = useReadContract({
    address: token0Address,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && isConfiguredAddress(token0Address) },
  });

  const { data: token1Balance } = useReadContract({
    address: token1Address,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && isConfiguredAddress(token1Address) },
  });

  const { data: token0Allowance } = useReadContract({
    address: token0Address,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address, ADDRESSES.AMM],
    query: { enabled: !!address && isConfiguredAddress(token0Address) && configured },
  });

  const { data: token1Allowance } = useReadContract({
    address: token1Address,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address, ADDRESSES.AMM],
    query: { enabled: !!address && isConfiguredAddress(token1Address) && configured },
  });

  const { data: lpBalance } = useReadContract({
    address: lpTokenAddress,
    abi: LP_TOKEN_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled: !!address && isConfiguredAddress(lpTokenAddress) },
  });

  const { data: lpTotalSupply } = useReadContract({
    address: lpTokenAddress,
    abi: LP_TOKEN_ABI,
    functionName: "totalSupply",
    query: { enabled: isConfiguredAddress(lpTokenAddress) },
  });

  const swapAmountWei = parseTokenInput(swapAmount);
  const liquidity0Wei = parseTokenInput(liquidity0);
  const liquidity1Wei = parseTokenInput(liquidity1);
  const removeLpAmountWei = parseTokenInput(removeLpAmount);

  const reserveIn = reserves ? (swapDirection === "0to1" ? reserves[0] : reserves[1]) : undefined;
  const reserveOut = reserves ? (swapDirection === "0to1" ? reserves[1] : reserves[0]) : undefined;

  const { data: quotedAmountOut } = useReadContract({
    address: ADDRESSES.AMM,
    abi: AMM_ABI,
    functionName: "getAmountOut",
    args:
      reserveIn !== undefined && reserveOut !== undefined
        ? [swapAmountWei, reserveIn, reserveOut]
        : [0n, 1n, 1n],
    query: {
      enabled:
        configured && swapAmountWei > 0n && reserveIn !== undefined && reserveOut !== undefined,
    },
  });

  const { writeContract, data: txHash, isPending, error } = useWriteContract();

  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) {
      toast?.success("Transaction confirmed.");
      refetchReserves();
    }
  }, [isSuccess, refetchReserves, toast]);

  useEffect(() => {
    if (error) toast?.error(parseContractError(error));
  }, [error, toast]);

  const needsToken0Approval =
    swapAmountWei > 0n && swapDirection === "0to1" && (token0Allowance || 0n) < swapAmountWei;
  const needsToken1Approval =
    swapAmountWei > 0n && swapDirection === "1to0" && (token1Allowance || 0n) < swapAmountWei;
  const needsLiquidity0Approval = liquidity0Wei > 0n && (token0Allowance || 0n) < liquidity0Wei;
  const needsLiquidity1Approval = liquidity1Wei > 0n && (token1Allowance || 0n) < liquidity1Wei;

  const approveToken = (tokenAddress) => {
    writeContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [ADDRESSES.AMM, MAX_UINT256],
    });
  };

  const handleSwap = () => {
    if (swapAmountWei === 0n || !quotedAmountOut) {
      toast?.error("Enter a valid swap amount.");
      return;
    }

    const minAmountOut = (quotedAmountOut * 95n) / 100n;
    writeContract({
      address: ADDRESSES.AMM,
      abi: AMM_ABI,
      functionName:
        swapDirection === "0to1" ? "swapExactToken0ForToken1" : "swapExactToken1ForToken0",
      args: [swapAmountWei, minAmountOut, address],
    });
  };

  const handleAddLiquidity = () => {
    if (liquidity0Wei === 0n || liquidity1Wei === 0n) {
      toast?.error("Enter both liquidity amounts.");
      return;
    }

    writeContract({
      address: ADDRESSES.AMM,
      abi: AMM_ABI,
      functionName: "addLiquidity",
      args: [liquidity0Wei, liquidity1Wei, address],
    });
  };

  const handleRemoveLiquidity = () => {
    if (removeLpAmountWei === 0n) {
      toast?.error("Enter an LP amount to remove.");
      return;
    }

    writeContract({
      address: ADDRESSES.AMM,
      abi: AMM_ABI,
      functionName: "removeLiquidity",
      args: [removeLpAmountWei, address],
    });
  };

  return (
    <div className="page">
      <h1 className="page-title">AMM Marketplace</h1>

      <ConfigNotice
        title="Frontend contract config"
        lines={!configured ? ["Set VITE_AMM_ADDRESS and related token addresses."] : []}
      />

      <div className="grid-2 section-gap">
        <div className="card">
          <div className="card-title">Pool Addresses</div>
          <div className="stat-row">
            <span className="label">Token 0</span>
            <span className="value mono">{shortAddress(token0Address)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Token 1</span>
            <span className="value mono">{shortAddress(token1Address)}</span>
          </div>
          <div className="stat-row">
            <span className="label">LP Token</span>
            <span className="value mono">{shortAddress(lpTokenAddress)}</span>
          </div>
        </div>

        <div className="card">
          <div className="card-title">Pool State</div>
          <div className="stat-row">
            <span className="label">Reserve 0</span>
            <span className="value">{formatToken(reserves?.[0])}</span>
          </div>
          <div className="stat-row">
            <span className="label">Reserve 1</span>
            <span className="value">{formatToken(reserves?.[1])}</span>
          </div>
          <div className="stat-row">
            <span className="label">LP Supply</span>
            <span className="value">{formatToken(lpTotalSupply)}</span>
          </div>
        </div>
      </div>

      <Panel title="Your Balances">
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to load balances.</p>
        ) : (
          <div className="grid-2">
            <div className="stat-row">
              <span className="label">{token0Symbol || "Token 0"}</span>
              <span className="value">{formatToken(token0Balance)}</span>
            </div>
            <div className="stat-row">
              <span className="label">{token1Symbol || "Token 1"}</span>
              <span className="value">{formatToken(token1Balance)}</span>
            </div>
            <div className="stat-row">
              <span className="label">LP balance</span>
              <span className="value">{formatToken(lpBalance)}</span>
            </div>
          </div>
        )}
      </Panel>

      <Panel title="Swap">
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to swap.</p>
        ) : (
          <>
            <div
              style={{ display: "flex", gap: "0.75rem", marginBottom: "0.75rem", flexWrap: "wrap" }}
            >
              <select
                value={swapDirection}
                onChange={(event) => setSwapDirection(event.target.value)}
                style={{ maxWidth: "220px" }}
              >
                <option value="0to1">
                  {token0Symbol || "Token 0"} to {token1Symbol || "Token 1"}
                </option>
                <option value="1to0">
                  {token1Symbol || "Token 1"} to {token0Symbol || "Token 0"}
                </option>
              </select>
              <input
                type="number"
                min="0"
                placeholder="Swap amount"
                value={swapAmount}
                onChange={(event) => setSwapAmount(event.target.value)}
                style={{ maxWidth: "220px" }}
              />
            </div>

            <div className="stat-row">
              <span className="label">Quoted output</span>
              <span className="value">{formatToken(quotedAmountOut)}</span>
            </div>
            <div className="stat-row" style={{ marginBottom: "0.75rem" }}>
              <span className="label">Minimum out (5% slippage)</span>
              <span className="value">
                {quotedAmountOut ? formatToken((quotedAmountOut * 95n) / 100n) : "--"}
              </span>
            </div>

            {needsToken0Approval && (
              <button
                className="btn-secondary"
                onClick={() => approveToken(token0Address)}
                style={{ marginRight: "0.75rem" }}
              >
                Approve {token0Symbol || "Token 0"}
              </button>
            )}
            {needsToken1Approval && (
              <button
                className="btn-secondary"
                onClick={() => approveToken(token1Address)}
                style={{ marginRight: "0.75rem" }}
              >
                Approve {token1Symbol || "Token 1"}
              </button>
            )}

            <button className="btn-primary" disabled={isPending || confirming} onClick={handleSwap}>
              {isPending || confirming ? "Submitting..." : "Swap"}
            </button>
          </>
        )}
      </Panel>

      <Panel title="Add Liquidity">
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to add liquidity.</p>
        ) : (
          <>
            <div
              style={{ display: "flex", gap: "0.75rem", marginBottom: "0.75rem", flexWrap: "wrap" }}
            >
              <input
                type="number"
                min="0"
                placeholder={`${token0Symbol || "Token 0"} amount`}
                value={liquidity0}
                onChange={(event) => setLiquidity0(event.target.value)}
              />
              <input
                type="number"
                min="0"
                placeholder={`${token1Symbol || "Token 1"} amount`}
                value={liquidity1}
                onChange={(event) => setLiquidity1(event.target.value)}
              />
            </div>

            {needsLiquidity0Approval && (
              <button
                className="btn-secondary"
                onClick={() => approveToken(token0Address)}
                style={{ marginRight: "0.75rem" }}
              >
                Approve {token0Symbol || "Token 0"}
              </button>
            )}
            {needsLiquidity1Approval && (
              <button
                className="btn-secondary"
                onClick={() => approveToken(token1Address)}
                style={{ marginRight: "0.75rem" }}
              >
                Approve {token1Symbol || "Token 1"}
              </button>
            )}

            <button
              className="btn-primary"
              disabled={isPending || confirming}
              onClick={handleAddLiquidity}
            >
              {isPending || confirming ? "Submitting..." : "Add Liquidity"}
            </button>
          </>
        )}
      </Panel>

      <Panel title="Remove Liquidity">
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to remove liquidity.</p>
        ) : (
          <>
            <input
              type="number"
              min="0"
              placeholder="LP amount"
              value={removeLpAmount}
              onChange={(event) => setRemoveLpAmount(event.target.value)}
              style={{ maxWidth: "240px", marginBottom: "0.75rem" }}
            />
            <div>
              <button
                className="btn-primary"
                disabled={isPending || confirming}
                onClick={handleRemoveLiquidity}
              >
                {isPending || confirming ? "Submitting..." : "Remove Liquidity"}
              </button>
            </div>
          </>
        )}
      </Panel>
    </div>
  );
}
