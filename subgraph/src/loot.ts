import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  LootRequested,
  LootFulfilled,
} from "../generated/GameFiLoot/GameFiLoot";
import { LootDrop } from "../generated/schema";

export function handleLootRequested(event: LootRequested): void {
  let drop           = new LootDrop(event.transaction.hash.concatI32(event.logIndex.toI32()));
  drop.requester     = event.params.requester;
  drop.requestId     = event.params.requestId;
  drop.randomWords   = [];
  drop.itemsGranted  = [];
  drop.fulfilled     = false;
  drop.requestedAt   = event.block.timestamp;
  drop.txHash        = event.transaction.hash;
  drop.save();
}

export function handleLootFulfilled(event: LootFulfilled): void {
  // Find the matching request by requestId (scan is acceptable for small datasets)
  // In production, store requestId → entity ID in a mapping entity
  let id = event.transaction.hash.concatI32(event.logIndex.toI32());
  let drop = LootDrop.load(id);
  if (!drop) {
    drop              = new LootDrop(id);
    drop.requester    = Bytes.empty();
    drop.requestedAt  = event.block.timestamp;
    drop.txHash       = event.transaction.hash;
  }
  drop.requestId    = event.params.requestId;
  drop.randomWords  = event.params.randomWords;
  drop.itemsGranted = event.params.itemIds;
  drop.fulfilled    = true;
  drop.fulfilledAt  = event.block.timestamp;
  drop.save();
}
