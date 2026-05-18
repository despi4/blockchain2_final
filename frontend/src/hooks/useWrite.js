import { useWriteContract as useWagmiWrite } from "wagmi";

// Arbitrum Sepolia baseFee fluctuates around 0.01-0.025 gwei.
// wagmi/viem sometimes estimates maxFeePerGas just below baseFee, causing
// "max fee per gas less than block base fee" reverts. 0.05 gwei gives a safe
// buffer without triggering MetaMask's "high fee" warning.
const GAS = {
  maxFeePerGas: 50_000_000n, // 0.05 gwei
  maxPriorityFeePerGas: 1_000_000n, // 0.001 gwei
};

export function useWriteContract() {
  const { writeContract: _write, writeContractAsync: _writeAsync, ...rest } = useWagmiWrite();

  const writeContract = (params, options) => _write({ ...GAS, ...params }, options);
  const writeContractAsync = (params, options) => _writeAsync({ ...GAS, ...params }, options);

  return { writeContract, writeContractAsync, ...rest };
}
