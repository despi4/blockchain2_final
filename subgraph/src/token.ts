import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Transfer,
  DelegateChanged,
  DelegateVotesChanged,
} from "../generated/GameFiToken/GameFiToken";
import { TokenHolder } from "../generated/schema";

function loadOrCreate(address: Bytes): TokenHolder {
  let holder = TokenHolder.load(address);
  if (!holder) {
    holder             = new TokenHolder(address);
    holder.address     = address;
    holder.balance     = BigInt.zero();
    holder.votingPower = BigInt.zero();
    holder.delegate    = address;
  }
  return holder;
}

export function handleTransfer(event: Transfer): void {
  let ZERO = Bytes.fromHexString("0x0000000000000000000000000000000000000000");

  if (event.params.from.notEqual(ZERO)) {
    let from   = loadOrCreate(event.params.from);
    from.balance = from.balance.minus(event.params.value);
    from.save();
  }

  if (event.params.to.notEqual(ZERO)) {
    let to   = loadOrCreate(event.params.to);
    to.balance = to.balance.plus(event.params.value);
    to.save();
  }
}

export function handleDelegateChanged(event: DelegateChanged): void {
  let holder    = loadOrCreate(event.params.delegator);
  holder.delegate = event.params.toDelegate;
  holder.save();
}

export function handleDelegateVotesChanged(event: DelegateVotesChanged): void {
  let holder          = loadOrCreate(event.params.delegate);
  holder.votingPower  = event.params.newBalance;
  holder.save();
}
