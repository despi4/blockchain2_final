import { BigDecimal, BigInt } from "@graphprotocol/graph-ts";
import { Swap as SwapEvent } from "../generated/GameFiAMM/GameFiAMM";
import { GameFiAMM } from "../generated/GameFiAMM/GameFiAMM";
import { Swap, VaultDayData } from "../generated/schema";

export function handleSwap(event: SwapEvent): void {
  let swap         = new Swap(event.transaction.hash.concatI32(event.logIndex.toI32()));
  swap.sender      = event.params.sender;
  swap.amount0In   = event.params.amount0In;
  swap.amount1In   = event.params.amount1In;
  swap.amount0Out  = event.params.amount0Out;
  swap.amount1Out  = event.params.amount1Out;
  swap.to          = event.params.to;
  swap.timestamp   = event.block.timestamp;
  swap.blockNumber = event.block.number;
  swap.txHash      = event.transaction.hash;
  swap.save();

  // Update daily vault snapshot
  let dayId   = event.block.timestamp.toI32() / 86400;
  let dateStr = dayId.toString();
  let snapshot = VaultDayData.load(dateStr);
  if (!snapshot) {
    snapshot              = new VaultDayData(dateStr);
    snapshot.date         = dayId;
    snapshot.totalAssets  = BigInt.zero();
    snapshot.totalSupply  = BigInt.zero();
    snapshot.pricePerShare = BigDecimal.zero();
  }

  // Read live reserves from contract
  let contract   = GameFiAMM.bind(event.address);
  let reserveRes = contract.try_getReserves();
  if (!reserveRes.reverted) {
    snapshot.totalAssets = reserveRes.value.get_reserve0().plus(reserveRes.value.get_reserve1());
  }
  snapshot.save();
}
