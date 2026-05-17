import { ItemCrafted } from "../generated/GameFiCrafting/GameFiCrafting";
import { CraftingEvent } from "../generated/schema";

export function handleItemCrafted(event: ItemCrafted): void {
  let craft           = new CraftingEvent(event.transaction.hash.concatI32(event.logIndex.toI32()));
  craft.crafter       = event.params.crafter;
  craft.inputItems    = event.params.inputIds;
  craft.inputAmounts  = event.params.inputAmounts;
  craft.outputItem    = event.params.outputId;
  craft.outputAmount  = event.params.outputAmount;
  craft.timestamp     = event.block.timestamp;
  craft.txHash        = event.transaction.hash;
  craft.save();
}
