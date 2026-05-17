import { formatUnits, parseUnits } from "viem";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function formatToken(value, decimals = 18, maxFractionDigits = 4) {
  if (value === undefined || value === null) return "--";

  try {
    const number = Number.parseFloat(formatUnits(value, decimals));
    if (!Number.isFinite(number)) return "--";
    return number.toLocaleString(undefined, { maximumFractionDigits: maxFractionDigits });
  } catch {
    return "--";
  }
}

export function parseTokenInput(value, decimals = 18) {
  if (!value) return 0n;

  try {
    return parseUnits(value, decimals);
  } catch {
    return 0n;
  }
}

export function shortAddress(address) {
  if (!address || address === ZERO_ADDRESS) return "Not set";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function timestampToLocal(value) {
  if (!value) return "--";
  return new Date(Number(value) * 1000).toLocaleString();
}

export function basisPointsToPercent(bps) {
  if (bps === undefined || bps === null) return "--";
  return `${(Number(bps) / 100).toFixed(2)}%`;
}
