import { Crafted } from "../generated/CraftingSystem/CraftingSystem";
import { CraftingEvent } from "../generated/schema";

export function handleCrafted(event: Crafted): void {
  let id = event.transaction.hash.toHexString().concat("-").concat(event.logIndex.toString());
  let craftingEvent = new CraftingEvent(id);

  craftingEvent.user = event.params.user;
  craftingEvent.recipeId = event.params.recipeId;
  craftingEvent.amount = event.params.amount;
  craftingEvent.outputItemId = event.params.outputItemId;
  craftingEvent.outputAmount = event.params.outputAmount;
  craftingEvent.timestamp = event.block.timestamp;
  craftingEvent.txHash = event.transaction.hash;

  craftingEvent.save();
}
