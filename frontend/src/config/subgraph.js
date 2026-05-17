// Replace with your deployed subgraph URL
export const SUBGRAPH_URL =
  "https://api.studio.thegraph.com/query/YOUR_ID/gamefi-economy/version/latest";

const query = async (gql, variables = {}) => {
  const res = await fetch(SUBGRAPH_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query: gql, variables }),
  });
  if (!res.ok) throw new Error(`Subgraph HTTP error ${res.status}`);
  const json = await res.json();
  if (json.errors?.length) throw new Error(json.errors[0].message);
  return json.data;
};

// ── GraphQL Queries ─────────────────────────────────────────────────────────

export const fetchRecentSwaps = (first = 10) =>
  query(`{
    swaps(first: ${first}, orderBy: timestamp, orderDirection: desc) {
      id
      sender
      amount0In
      amount1In
      amount0Out
      amount1Out
      timestamp
    }
  }`);

export const fetchProposals = (first = 20) =>
  query(`{
    proposals(first: ${first}, orderBy: createdAt, orderDirection: desc) {
      id
      proposalId
      proposer
      description
      status
      forVotes
      againstVotes
      abstainVotes
      createdAt
      voteEnd
    }
  }`);

export const fetchVaultStats = () =>
  query(`{
    vaultDayDatas(first: 7, orderBy: date, orderDirection: desc) {
      id
      date
      totalAssets
      totalSupply
      pricePerShare
    }
  }`);

export const fetchTokenHolders = (first = 10) =>
  query(`{
    tokenHolders(first: ${first}, orderBy: balance, orderDirection: desc) {
      id
      address
      balance
      votingPower
    }
  }`);

export const fetchUserActivity = (address) =>
  query(
    `query UserActivity($addr: String!) {
      swaps(where: { sender: $addr }, first: 5, orderBy: timestamp, orderDirection: desc) {
        id
        amount0In
        amount1Out
        timestamp
      }
      votes(where: { voter: $addr }, first: 5) {
        id
        proposalId
        support
        weight
      }
    }`,
    { addr: address?.toLowerCase() }
  );
