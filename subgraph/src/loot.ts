import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { LootFulfilled, LootRequested } from "../generated/LootDrop/LootDrop";
import { LootDrop } from "../generated/schema";

let ZERO_BYTES = changetype<Bytes>(Bytes.fromHexString("0x0000000000000000000000000000000000000000"));

function loadOrCreateDrop(requestId: BigInt): LootDrop {
  let id = requestId.toString();
  let drop = LootDrop.load(id);

  if (drop == null) {
    drop = new LootDrop(id);
    drop.requester = ZERO_BYTES;
    drop.requestId = requestId;
    drop.feePaid = BigInt.fromI32(0);
    drop.fulfilled = false;
    drop.requestedAt = BigInt.fromI32(0);
    drop.txHash = ZERO_BYTES;
  }

  return drop;
}

export function handleLootRequested(event: LootRequested): void {
  let drop = loadOrCreateDrop(event.params.requestId);

  drop.requester = event.params.user;
  drop.requestId = event.params.requestId;
  drop.feePaid = event.params.feePaid;
  drop.fulfilled = false;
  drop.requestedAt = event.block.timestamp;
  drop.txHash = event.transaction.hash;

  drop.save();
}

export function handleLootFulfilled(event: LootFulfilled): void {
  let drop = loadOrCreateDrop(event.params.requestId);

  drop.requester = event.params.user;
  drop.itemGranted = event.params.itemId;
  drop.randomness = event.params.randomness;
  drop.fulfilled = true;
  drop.fulfilledAt = event.block.timestamp;
  drop.txHash = event.transaction.hash;

  drop.save();
}
