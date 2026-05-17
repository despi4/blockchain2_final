import { useEffect, useState } from "react";
import ConfigNotice from "../components/ConfigNotice";
import {
  fetchProposals,
  fetchRecentCrafting,
  fetchRecentLootDrops,
  fetchRecentRentals,
  fetchRecentSwaps,
  fetchTokenHolders,
  fetchVaultStats,
} from "../config/subgraph";
import { shortAddress, timestampToLocal } from "../utils/format";

function Section({ title, children }) {
  return (
    <div className="card section-gap">
      <div className="card-title" style={{ marginBottom: "0.75rem" }}>
        {title}
      </div>
      {children}
    </div>
  );
}

export default function SubgraphPage() {
  const [data, setData] = useState({
    swaps: null,
    proposals: null,
    vault: null,
    holders: null,
    loot: null,
    crafting: null,
    rentals: null,
  });
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    Promise.all([
      fetchRecentSwaps(5),
      fetchProposals(5),
      fetchVaultStats(),
      fetchTokenHolders(5),
      fetchRecentLootDrops(5),
      fetchRecentCrafting(5),
      fetchRecentRentals(5),
    ])
      .then(([swaps, proposals, vault, holders, loot, crafting, rentals]) => {
        setData({
          swaps: swaps?.swaps || [],
          proposals: proposals?.proposals || [],
          vault: vault?.vaultDayDatas || [],
          holders: holders?.tokenHolders || [],
          loot: loot?.lootDrops || [],
          crafting: crafting?.craftingEvents || [],
          rentals: rentals?.rentalActivities || [],
        });
      })
      .catch(() => setFailed(true));
  }, []);

  return (
    <div className="page">
      <h1 className="page-title">Subgraph Data</h1>

      <ConfigNotice
        title="Subgraph configuration"
        lines={
          failed
            ? [
                "Set VITE_SUBGRAPH_URL to a deployed Graph endpoint and ensure the subgraph is live.",
              ]
            : []
        }
      />

      <Section title="Recent swaps">
        {data.swaps === null && !failed && <span className="spinner" />}
        {data.swaps?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Sender</th>
                <th>In</th>
                <th>Out</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {data.swaps.map((swap) => (
                <tr key={swap.id}>
                  <td className="mono">{shortAddress(swap.sender)}</td>
                  <td className="mono">{swap.amountIn}</td>
                  <td className="mono">{swap.amountOut}</td>
                  <td className="text-sm text-muted">{timestampToLocal(swap.timestamp)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>

      <Section title="Recent proposals">
        {data.proposals?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Proposal</th>
                <th>Status</th>
                <th>Proposer</th>
              </tr>
            </thead>
            <tbody>
              {data.proposals.map((proposal) => (
                <tr key={proposal.id}>
                  <td className="mono">{proposal.proposalId}</td>
                  <td>{proposal.status}</td>
                  <td className="mono">{shortAddress(proposal.proposer)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>

      <Section title="Vault snapshots">
        {data.vault?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Total Assets</th>
                <th>Total Supply</th>
                <th>Price / Share</th>
              </tr>
            </thead>
            <tbody>
              {data.vault.map((entry) => (
                <tr key={entry.id}>
                  <td>{entry.id}</td>
                  <td>{entry.totalAssets}</td>
                  <td>{entry.totalSupply}</td>
                  <td>{entry.pricePerShare}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>

      <Section title="Top token holders">
        {data.holders?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Holder</th>
                <th>Balance</th>
                <th>Voting Power</th>
              </tr>
            </thead>
            <tbody>
              {data.holders.map((holder) => (
                <tr key={holder.id}>
                  <td className="mono">{shortAddress(holder.address)}</td>
                  <td>{holder.balance}</td>
                  <td>{holder.votingPower}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>

      <Section title="Recent loot drops">
        {data.loot?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Requester</th>
                <th>Item</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {data.loot.map((entry) => (
                <tr key={entry.id}>
                  <td className="mono">{shortAddress(entry.requester)}</td>
                  <td>{entry.itemGranted || "--"}</td>
                  <td>{entry.fulfilled ? "Fulfilled" : "Pending"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>

      <Section title="Recent crafting events">
        {data.crafting?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Crafter</th>
                <th>Output</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {data.crafting.map((entry) => (
                <tr key={entry.id}>
                  <td className="mono">{shortAddress(entry.user)}</td>
                  <td>
                    {entry.outputItemId} x{entry.outputAmount}
                  </td>
                  <td className="text-sm text-muted">{timestampToLocal(entry.timestamp)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>

      <Section title="Recent rental activity">
        {data.rentals?.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Listing</th>
                <th>Renter</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {data.rentals.map((entry) => (
                <tr key={entry.id}>
                  <td>{entry.eventType}</td>
                  <td className="mono">{entry.listingId}</td>
                  <td className="mono">{entry.renter ? shortAddress(entry.renter) : "--"}</td>
                  <td className="text-sm text-muted">{timestampToLocal(entry.timestamp)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>
    </div>
  );
}
