import { useEffect, useState } from "react";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import {
  ADDRESSES,
  ERC20_ABI,
  GAME_ITEMS_ABI,
  ITEM_IDS,
  ITEM_METADATA,
  RENTAL_VAULT_ABI,
  isConfiguredAddress,
} from "../config/contracts";
import ConfigNotice from "../components/ConfigNotice";
import { parseContractError } from "../hooks/useToast";
import {
  basisPointsToPercent,
  formatToken,
  parseTokenInput,
  shortAddress,
  timestampToLocal,
} from "../utils/format";

const MAX_UINT256 = 2n ** 256n - 1n;
const LISTING_STATUS = ["None", "Listed", "Rented", "Returned", "Cancelled"];
const RENTAL_STATUS = ["None", "Active", "Ended"];

function itemLabel(itemId) {
  return ITEM_METADATA[itemId]?.name || `Item ${itemId}`;
}

export default function Rental({ toast }) {
  const { address, isConnected } = useAccount();
  const [itemId, setItemId] = useState("1");
  const [amount, setAmount] = useState("1");
  const [pricePerDay, setPricePerDay] = useState("");
  const [maxDuration, setMaxDuration] = useState("1");
  const [rentListingId, setRentListingId] = useState("");
  const [rentDuration, setRentDuration] = useState("1");
  const [endRentalId, setEndRentalId] = useState("");
  const [cancelListingId, setCancelListingId] = useState("");

  const configured = {
    rental: isConfiguredAddress(ADDRESSES.RENTAL_VAULT),
    items: isConfiguredAddress(ADDRESSES.GAME_ITEMS),
    gold: isConfiguredAddress(ADDRESSES.GOLD_TOKEN),
  };

  const { data: itemApproval } = useReadContract({
    address: ADDRESSES.GAME_ITEMS,
    abi: GAME_ITEMS_ABI,
    functionName: "isApprovedForAll",
    args: [address, ADDRESSES.RENTAL_VAULT],
    query: { enabled: !!address && configured.items && configured.rental },
  });

  const { data: goldAllowance } = useReadContract({
    address: ADDRESSES.GOLD_TOKEN,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address, ADDRESSES.RENTAL_VAULT],
    query: { enabled: !!address && configured.gold && configured.rental },
  });

  const { data: claimableEarnings } = useReadContract({
    address: ADDRESSES.RENTAL_VAULT,
    abi: RENTAL_VAULT_ABI,
    functionName: "claimableEarnings",
    args: [address],
    query: { enabled: !!address && configured.rental },
  });

  const { data: protocolFeeBps } = useReadContract({
    address: ADDRESSES.RENTAL_VAULT,
    abi: RENTAL_VAULT_ABI,
    functionName: "protocolFeeBps",
    query: { enabled: configured.rental },
  });

  const { data: nextListingId } = useReadContract({
    address: ADDRESSES.RENTAL_VAULT,
    abi: RENTAL_VAULT_ABI,
    functionName: "nextListingId",
    query: { enabled: configured.rental },
  });

  const listingIds = [];
  for (let id = 1; id <= Number(nextListingId || 0n); id += 1) {
    listingIds.push(id);
  }

  const listingContracts = listingIds.map((listingId) => ({
    address: ADDRESSES.RENTAL_VAULT,
    abi: RENTAL_VAULT_ABI,
    functionName: "listings",
    args: [BigInt(listingId)],
  }));

  const { data: listingResults } = useReadContracts({
    contracts: listingContracts,
    query: { enabled: configured.rental && listingIds.length > 0 },
  });

  const activeRentalIds = (listingResults || [])
    .map((entry) => entry?.result?.[6])
    .filter((value) => value && value > 0n);

  const rentalContracts = activeRentalIds.map((rentalId) => ({
    address: ADDRESSES.RENTAL_VAULT,
    abi: RENTAL_VAULT_ABI,
    functionName: "rentals",
    args: [rentalId],
  }));

  const { data: rentalResults } = useReadContracts({
    contracts: rentalContracts,
    query: { enabled: configured.rental && activeRentalIds.length > 0 },
  });

  const selectedListing = listingResults?.[Number(rentListingId) - 1]?.result;
  const rentCost = selectedListing ? selectedListing[3] * BigInt(rentDuration || "0") : 0n;
  const needsGoldApproval = rentCost > 0n && (goldAllowance || 0n) < rentCost;

  const { writeContract, data: txHash, isPending, error } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) toast?.success("Rental transaction confirmed.");
  }, [isSuccess, toast]);

  useEffect(() => {
    if (error) toast?.error(parseContractError(error));
  }, [error, toast]);

  return (
    <div className="page">
      <h1 className="page-title">Rental Vault</h1>

      <ConfigNotice
        title="Frontend contract config"
        lines={[
          ...(!configured.rental ? ["Set VITE_RENTAL_VAULT_ADDRESS."] : []),
          ...(!configured.items ? ["Set VITE_GAME_ITEMS_ADDRESS."] : []),
          ...(!configured.gold ? ["Set VITE_GOLD_TOKEN_ADDRESS."] : []),
        ]}
      />

      <div className="grid-2 section-gap">
        <div className="card">
          <div className="card-title">Rental state</div>
          <div className="stat-row">
            <span className="label">Vault</span>
            <span className="value mono">{shortAddress(ADDRESSES.RENTAL_VAULT)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Protocol fee</span>
            <span className="value">{basisPointsToPercent(protocolFeeBps)}</span>
          </div>
          <div className="stat-row">
            <span className="label">Claimable earnings</span>
            <span className="value">{formatToken(claimableEarnings)} GOLD</span>
          </div>
        </div>

        <div className="card">
          <div className="card-title">Approvals</div>
          <div className="stat-row">
            <span className="label">Item operator approval</span>
            <span className="value">{itemApproval ? "Granted" : "Missing"}</span>
          </div>
          <div className="stat-row">
            <span className="label">Gold allowance</span>
            <span className="value">{formatToken(goldAllowance)}</span>
          </div>
          <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap", marginTop: "0.75rem" }}>
            {!itemApproval && (
              <button
                className="btn-secondary"
                onClick={() =>
                  writeContract({
                    address: ADDRESSES.GAME_ITEMS,
                    abi: GAME_ITEMS_ABI,
                    functionName: "setApprovalForAll",
                    args: [ADDRESSES.RENTAL_VAULT, true],
                  })
                }
              >
                Approve items
              </button>
            )}
            <button
              className="btn-secondary"
              onClick={() =>
                writeContract({
                  address: ADDRESSES.GOLD_TOKEN,
                  abi: ERC20_ABI,
                  functionName: "approve",
                  args: [ADDRESSES.RENTAL_VAULT, MAX_UINT256],
                })
              }
            >
              Approve GOLD
            </button>
          </div>
        </div>
      </div>

      <div className="card section-gap">
        <div className="card-title">List item for rent</div>
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to create a listing.</p>
        ) : (
          <>
            <div className="grid-2" style={{ marginBottom: "0.75rem" }}>
              <select value={itemId} onChange={(event) => setItemId(event.target.value)}>
                {ITEM_IDS.map((id) => (
                  <option key={id} value={id}>
                    {itemLabel(id)}
                  </option>
                ))}
              </select>
              <input
                type="number"
                min="1"
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
                placeholder="Amount"
              />
              <input
                type="number"
                min="0"
                value={pricePerDay}
                onChange={(event) => setPricePerDay(event.target.value)}
                placeholder="Price per day in GOLD"
              />
              <input
                type="number"
                min="1"
                value={maxDuration}
                onChange={(event) => setMaxDuration(event.target.value)}
                placeholder="Max duration in days"
              />
            </div>

            <button
              className="btn-primary"
              disabled={!itemApproval || isPending || confirming}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.RENTAL_VAULT,
                  abi: RENTAL_VAULT_ABI,
                  functionName: "listItemForRent",
                  args: [
                    BigInt(itemId),
                    parseTokenInput(amount, 0),
                    parseTokenInput(pricePerDay),
                    Number(maxDuration),
                  ],
                })
              }
            >
              {isPending || confirming ? "Submitting..." : "Create listing"}
            </button>
          </>
        )}
      </div>

      <div className="card section-gap">
        <div className="card-title">Rent item</div>
        {!isConnected ? (
          <p className="text-sm text-muted">Connect wallet to rent.</p>
        ) : (
          <>
            <div className="grid-2" style={{ marginBottom: "0.75rem" }}>
              <input
                type="number"
                min="1"
                value={rentListingId}
                onChange={(event) => setRentListingId(event.target.value)}
                placeholder="Listing ID"
              />
              <input
                type="number"
                min="1"
                value={rentDuration}
                onChange={(event) => setRentDuration(event.target.value)}
                placeholder="Duration in days"
              />
            </div>
            <div className="stat-row" style={{ marginBottom: "0.75rem" }}>
              <span className="label">Estimated rent cost</span>
              <span className="value">{formatToken(rentCost)} GOLD</span>
            </div>
            {needsGoldApproval && (
              <button
                className="btn-secondary"
                onClick={() =>
                  writeContract({
                    address: ADDRESSES.GOLD_TOKEN,
                    abi: ERC20_ABI,
                    functionName: "approve",
                    args: [ADDRESSES.RENTAL_VAULT, MAX_UINT256],
                  })
                }
                style={{ marginRight: "0.75rem" }}
              >
                Approve GOLD
              </button>
            )}
            <button
              className="btn-primary"
              disabled={isPending || confirming}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.RENTAL_VAULT,
                  abi: RENTAL_VAULT_ABI,
                  functionName: "rentItem",
                  args: [BigInt(rentListingId || "0"), Number(rentDuration)],
                })
              }
            >
              {isPending || confirming ? "Submitting..." : "Rent item"}
            </button>
          </>
        )}
      </div>

      <div className="grid-2 section-gap">
        <div className="card">
          <div className="card-title">End rental</div>
          <input
            type="number"
            min="1"
            value={endRentalId}
            onChange={(event) => setEndRentalId(event.target.value)}
            placeholder="Rental ID"
            style={{ marginBottom: "0.75rem" }}
          />
          <button
            className="btn-primary"
            disabled={isPending || confirming}
            onClick={() =>
              writeContract({
                address: ADDRESSES.RENTAL_VAULT,
                abi: RENTAL_VAULT_ABI,
                functionName: "endRental",
                args: [BigInt(endRentalId || "0")],
              })
            }
          >
            {isPending || confirming ? "Submitting..." : "End rental"}
          </button>
        </div>

        <div className="card">
          <div className="card-title">Cancel listing / claim</div>
          <input
            type="number"
            min="1"
            value={cancelListingId}
            onChange={(event) => setCancelListingId(event.target.value)}
            placeholder="Listing ID"
            style={{ marginBottom: "0.75rem" }}
          />
          <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
            <button
              className="btn-secondary"
              disabled={isPending || confirming}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.RENTAL_VAULT,
                  abi: RENTAL_VAULT_ABI,
                  functionName: "cancelListing",
                  args: [BigInt(cancelListingId || "0")],
                })
              }
            >
              Cancel listing
            </button>
            <button
              className="btn-primary"
              disabled={isPending || confirming}
              onClick={() =>
                writeContract({
                  address: ADDRESSES.RENTAL_VAULT,
                  abi: RENTAL_VAULT_ABI,
                  functionName: "claimEarnings",
                })
              }
            >
              Claim earnings
            </button>
          </div>
        </div>
      </div>

      <div className="card section-gap">
        <div className="card-title">Listings</div>
        {listingIds.length === 0 ? (
          <p className="text-sm text-muted">No listings found yet.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Lender</th>
                <th>Item</th>
                <th>Amount</th>
                <th>Price/day</th>
                <th>Max days</th>
                <th>Status</th>
                <th>Rental</th>
              </tr>
            </thead>
            <tbody>
              {listingResults?.map((entry, index) => {
                const listing = entry?.result;
                if (!listing) return null;

                return (
                  <tr key={index + 1}>
                    <td>{index + 1}</td>
                    <td className="mono">{shortAddress(listing[0])}</td>
                    <td>{itemLabel(Number(listing[1]))}</td>
                    <td>{listing[2].toString()}</td>
                    <td>{formatToken(listing[3])}</td>
                    <td>{listing[4].toString()}</td>
                    <td>{LISTING_STATUS[Number(listing[5])] || "Unknown"}</td>
                    <td>{listing[6].toString()}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      <div className="card">
        <div className="card-title">Active rentals</div>
        {activeRentalIds.length === 0 ? (
          <p className="text-sm text-muted">No active rentals found.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Rental ID</th>
                <th>Listing ID</th>
                <th>Renter</th>
                <th>Ends</th>
                <th>Payment</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {rentalResults?.map((entry, index) => {
                const rental = entry?.result;
                if (!rental) return null;

                return (
                  <tr key={activeRentalIds[index].toString()}>
                    <td>{activeRentalIds[index].toString()}</td>
                    <td>{rental[0].toString()}</td>
                    <td className="mono">{shortAddress(rental[1])}</td>
                    <td className="text-sm text-muted">{timestampToLocal(rental[3])}</td>
                    <td>{formatToken(rental[4])}</td>
                    <td>{RENTAL_STATUS[Number(rental[6])] || "Unknown"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
