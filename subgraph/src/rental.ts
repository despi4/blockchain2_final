import { BigInt } from "@graphprotocol/graph-ts";
import {
  ItemListed,
  ItemRented,
  ListingCancelled,
  RentalEnded,
} from "../generated/ItemRentalVault/ItemRentalVault";
import { RentalActivity } from "../generated/schema";

function activityId(prefix: string, txHash: string, logIndex: BigInt): string {
  return prefix.concat("-").concat(txHash).concat("-").concat(logIndex.toString());
}

export function handleItemListed(event: ItemListed): void {
  let rentalActivity = new RentalActivity(
    activityId("listed", event.transaction.hash.toHexString(), event.logIndex)
  );

  rentalActivity.eventType = "LISTED";
  rentalActivity.listingId = event.params.listingId;
  rentalActivity.lender = event.params.lender;
  rentalActivity.itemId = event.params.itemId;
  rentalActivity.amount = event.params.amount;
  rentalActivity.pricePerDay = event.params.pricePerDay;
  rentalActivity.duration = BigInt.fromString(event.params.maxDuration.toString());
  rentalActivity.status = "LISTED";
  rentalActivity.timestamp = event.block.timestamp;
  rentalActivity.txHash = event.transaction.hash;

  rentalActivity.save();
}

export function handleItemRented(event: ItemRented): void {
  let rentalActivity = new RentalActivity(
    activityId("rented", event.transaction.hash.toHexString(), event.logIndex)
  );

  rentalActivity.eventType = "RENTED";
  rentalActivity.listingId = event.params.listingId;
  rentalActivity.rentalId = event.params.rentalId;
  rentalActivity.renter = event.params.renter;
  rentalActivity.duration = BigInt.fromString(event.params.duration.toString());
  rentalActivity.totalPayment = event.params.totalPayment;
  rentalActivity.protocolFee = event.params.protocolFee;
  rentalActivity.status = "RENTED";
  rentalActivity.timestamp = event.block.timestamp;
  rentalActivity.txHash = event.transaction.hash;

  rentalActivity.save();
}

export function handleRentalEnded(event: RentalEnded): void {
  let rentalActivity = new RentalActivity(
    activityId("ended", event.transaction.hash.toHexString(), event.logIndex)
  );

  rentalActivity.eventType = "ENDED";
  rentalActivity.listingId = event.params.listingId;
  rentalActivity.rentalId = event.params.rentalId;
  rentalActivity.lender = event.params.lender;
  rentalActivity.status = "ENDED";
  rentalActivity.timestamp = event.block.timestamp;
  rentalActivity.txHash = event.transaction.hash;

  rentalActivity.save();
}

export function handleListingCancelled(event: ListingCancelled): void {
  let rentalActivity = new RentalActivity(
    activityId("cancelled", event.transaction.hash.toHexString(), event.logIndex)
  );

  rentalActivity.eventType = "CANCELLED";
  rentalActivity.listingId = event.params.listingId;
  rentalActivity.lender = event.params.lender;
  rentalActivity.status = "CANCELLED";
  rentalActivity.timestamp = event.block.timestamp;
  rentalActivity.txHash = event.transaction.hash;

  rentalActivity.save();
}
