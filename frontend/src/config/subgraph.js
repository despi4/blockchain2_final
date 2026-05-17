export const SUBGRAPH_URL =
  import.meta.env.VITE_SUBGRAPH_URL ||
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

export const fetchRecentSwaps = (first = 10) =>
  query(`{
    swaps(first: ${first}, orderBy: timestamp, orderDirection: desc) {
      id
      sender
      tokenIn
      tokenOut
      amountIn
      amountOut
      timestamp
    }
  }`);

export const fetchRecentLootDrops = (first = 10) =>
  query(`{
    lootDrops(first: ${first}, orderBy: requestedAt, orderDirection: desc) {
      id
      requester
      requestId
      itemGranted
      randomness
      feePaid
      fulfilled
      requestedAt
      fulfilledAt
    }
  }`);

export const fetchRecentCrafting = (first = 10) =>
  query(`{
    craftingEvents(first: ${first}, orderBy: timestamp, orderDirection: desc) {
      id
      user
      recipeId
      amount
      outputItemId
      outputAmount
      timestamp
    }
  }`);

export const fetchRecentRentals = (first = 10) =>
  query(`{
    rentalActivities(first: ${first}, orderBy: timestamp, orderDirection: desc) {
      id
      eventType
      listingId
      rentalId
      lender
      renter
      itemId
      amount
      pricePerDay
      duration
      totalPayment
      protocolFee
      status
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
      lastUpdatedAt
    }
  }`);

export const fetchTokenHolders = (first = 10) =>
  query(`{
    tokenHolders(first: ${first}, orderBy: balance, orderDirection: desc) {
      id
      address
      balance
      votingPower
      delegate
    }
  }`);

export const fetchUserActivity = (address) =>
  query(
    `query UserActivity($addr: String!) {
      swaps(where: { sender: $addr }, first: 5, orderBy: timestamp, orderDirection: desc) {
        id
        amountIn
        amountOut
        tokenIn
        tokenOut
        timestamp
      }
      votes(where: { voter: $addr }, first: 5, orderBy: timestamp, orderDirection: desc) {
        id
        proposal {
          proposalId
        }
        support
        weight
        timestamp
      }
      rentalActivities(where: { renter: $addr }, first: 5, orderBy: timestamp, orderDirection: desc) {
        id
        eventType
        listingId
        rentalId
        timestamp
      }
    }`,
    { addr: address?.toLowerCase() }
  );
