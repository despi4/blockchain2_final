import { Swap as SwapEvent } from "../generated/ResourceAMM/ResourceAMM";
import { Swap } from "../generated/schema";

export function handleSwap(event: SwapEvent): void {
  let id = event.transaction.hash.toHexString().concat("-").concat(event.logIndex.toString());
  let swap = new Swap(id);

  swap.sender = event.params.sender;
  swap.tokenIn = event.params.tokenIn;
  swap.tokenOut = event.params.tokenOut;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.to = event.params.to;
  swap.timestamp = event.block.timestamp;
  swap.blockNumber = event.block.number;
  swap.txHash = event.transaction.hash;

  swap.save();
}
