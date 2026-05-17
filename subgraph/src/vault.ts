import { Address, BigDecimal, BigInt } from "@graphprotocol/graph-ts";
import { Deposit, GuildTreasuryVaultV1, Withdraw } from "../generated/GuildTreasuryVault/GuildTreasuryVaultV1";
import { VaultDayData } from "../generated/schema";

function syncVaultSnapshot(vaultAddress: Address, timestamp: BigInt): void {
  let day = timestamp.toI32() / 86_400;
  let id = day.toString();
  let snapshot = VaultDayData.load(id);

  if (snapshot == null) {
    snapshot = new VaultDayData(id);
    snapshot.date = day;
    snapshot.totalAssets = BigInt.fromI32(0);
    snapshot.totalSupply = BigInt.fromI32(0);
    snapshot.pricePerShare = BigDecimal.fromString("0");
    snapshot.lastUpdatedAt = timestamp;
  }

  let vault = GuildTreasuryVaultV1.bind(vaultAddress);
  let totalAssetsResult = vault.try_totalAssets();
  let totalSupplyResult = vault.try_totalSupply();

  if (!totalAssetsResult.reverted) {
    snapshot.totalAssets = totalAssetsResult.value;
  }

  if (!totalSupplyResult.reverted) {
    snapshot.totalSupply = totalSupplyResult.value;
  }

  if (snapshot.totalSupply.equals(BigInt.fromI32(0))) {
    snapshot.pricePerShare = BigDecimal.fromString("0");
  } else {
    snapshot.pricePerShare = snapshot.totalAssets.toBigDecimal().div(snapshot.totalSupply.toBigDecimal());
  }

  snapshot.lastUpdatedAt = timestamp;
  snapshot.save();
}

export function handleDeposit(event: Deposit): void {
  syncVaultSnapshot(event.address, event.block.timestamp);
}

export function handleWithdraw(event: Withdraw): void {
  syncVaultSnapshot(event.address, event.block.timestamp);
}
