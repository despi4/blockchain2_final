import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  DelegateChanged,
  DelegateVotesChanged,
  Transfer,
} from "../generated/GameGovernanceToken/GameGovernanceToken";
import { TokenHolder } from "../generated/schema";

function loadOrCreateHolder(addressHex: string, addressBytes: Bytes): TokenHolder {
  let holder = TokenHolder.load(addressHex);

  if (holder == null) {
    holder = new TokenHolder(addressHex);
    holder.address = addressBytes;
    holder.balance = BigInt.fromI32(0);
    holder.votingPower = BigInt.fromI32(0);
    holder.delegate = addressBytes;
  }

  return holder;
}

export function handleTransfer(event: Transfer): void {
  let zeroAddress = "0x0000000000000000000000000000000000000000";
  let fromHex = event.params.from.toHexString();
  let toHex = event.params.to.toHexString();

  if (fromHex != zeroAddress) {
    let fromHolder = loadOrCreateHolder(fromHex, event.params.from);
    fromHolder.balance = fromHolder.balance.minus(event.params.value);
    fromHolder.save();
  }

  if (toHex != zeroAddress) {
    let toHolder = loadOrCreateHolder(toHex, event.params.to);
    toHolder.balance = toHolder.balance.plus(event.params.value);
    toHolder.save();
  }
}

export function handleDelegateChanged(event: DelegateChanged): void {
  let holder = loadOrCreateHolder(event.params.delegator.toHexString(), event.params.delegator);
  holder.delegate = event.params.toDelegate;
  holder.save();
}

export function handleDelegateVotesChanged(event: DelegateVotesChanged): void {
  let holder = loadOrCreateHolder(event.params.delegate.toHexString(), event.params.delegate);
  holder.votingPower = event.params.newVotes;
  holder.save();
}
