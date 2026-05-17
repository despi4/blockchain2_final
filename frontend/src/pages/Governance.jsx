import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits } from "viem";
import {
  ADDRESSES,
  GOVERNOR_ABI,
  GOVERNANCE_TOKEN_ABI,
  PROPOSAL_STATE,
  PROPOSAL_STATE_COLOR,
} from "../config/contracts";
import { fetchProposals } from "../config/subgraph";
import { parseContractError } from "../hooks/useToast";

// Known proposal IDs to display (populated from subgraph / events)
// In production these come from the subgraph; we also allow manual entry.
const VOTE_SUPPORT = { 0: "Against", 1: "For", 2: "Abstain" };

function StateBadge({ state }) {
  const label = PROPOSAL_STATE[state] ?? "Unknown";
  return (
    <span
      className="badge"
      style={{
        background: `${PROPOSAL_STATE_COLOR[label] ?? "#6b7280"}22`,
        color: PROPOSAL_STATE_COLOR[label] ?? "#6b7280",
        border: `1px solid ${PROPOSAL_STATE_COLOR[label] ?? "#6b7280"}55`,
      }}
    >
      {label}
    </span>
  );
}

function fmt(val, decimals = 18, dp = 2) {
  if (val === undefined || val === null) return "—";
  try {
    return parseFloat(formatUnits(val, decimals)).toLocaleString(undefined, {
      maximumFractionDigits: dp,
    });
  } catch {
    return "—";
  }
}

function ProposalRow({ proposalId, address, toast }) {
  const [support, setSupport] = useState(1); // default: For
  const idBig = BigInt(proposalId);

  const { data: state } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "state",
    args: [idBig],
  });
  const { data: votes } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "proposalVotes",
    args: [idBig],
  });
  const { data: hasVoted } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "hasVoted",
    args: [idBig, address],
    query: { enabled: !!address },
  });
  const { data: deadline } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "proposalDeadline",
    args: [idBig],
  });

  const { writeContract, data: voteTxHash, isPending, error: voteError } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: voteTxHash });

  useEffect(() => {
    if (isSuccess) toast?.success("Vote cast!");
  }, [isSuccess]);
  useEffect(() => {
    if (voteError) toast?.error(parseContractError(voteError));
  }, [voteError]);

  const isActive = state === 1;

  const totalVotes = votes ? Number(formatUnits(votes[0] + votes[1] + votes[2], 18)) : 0;
  const forPct =
    totalVotes > 0 ? (Number(formatUnits(votes?.[1] ?? 0n, 18)) / totalVotes) * 100 : 0;

  return (
    <div className="card" style={{ marginBottom: "1rem" }}>
      <div className="flex-between" style={{ marginBottom: "0.5rem" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <span className="mono text-muted text-sm">#{proposalId.slice(0, 8)}…</span>
          {state !== undefined && <StateBadge state={state} />}
        </div>
        {deadline !== undefined && (
          <span className="text-sm text-muted">Deadline: block {deadline.toString()}</span>
        )}
      </div>

      {/* Vote counts */}
      {votes && (
        <div style={{ marginBottom: "0.75rem" }}>
          <div
            style={{
              display: "flex",
              height: "6px",
              borderRadius: "4px",
              overflow: "hidden",
              background: "var(--border)",
              marginBottom: "0.4rem",
            }}
          >
            <div style={{ width: `${forPct}%`, background: "var(--success)" }} />
          </div>
          <div style={{ display: "flex", gap: "1.5rem", fontSize: "0.8rem" }}>
            <span style={{ color: "var(--success)" }}>For: {fmt(votes[1])}</span>
            <span style={{ color: "var(--danger)" }}>Against: {fmt(votes[0])}</span>
            <span style={{ color: "var(--text2)" }}>Abstain: {fmt(votes[2])}</span>
          </div>
        </div>
      )}

      {/* Vote UI */}
      {isActive && (
        <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
          {hasVoted ? (
            <span className="text-sm text-muted">Already voted.</span>
          ) : !address ? (
            <span className="text-sm text-muted">Connect wallet to vote.</span>
          ) : (
            <>
              <select
                value={support}
                onChange={(e) => setSupport(Number(e.target.value))}
                style={{ width: "auto", flex: 0 }}
              >
                <option value={1}>For</option>
                <option value={0}>Against</option>
                <option value={2}>Abstain</option>
              </select>
              <button
                className="btn-primary"
                disabled={isPending || confirming}
                onClick={() =>
                  writeContract({
                    address: ADDRESSES.GOVERNOR,
                    abi: GOVERNOR_ABI,
                    functionName: "castVote",
                    args: [idBig, support],
                  })
                }
              >
                {isPending || confirming ? (
                  <>
                    <span className="spinner" style={{ width: 12, height: 12 }} /> Voting…
                  </>
                ) : (
                  `Vote ${VOTE_SUPPORT[support]}`
                )}
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );
}

export default function Governance({ toast }) {
  const { address } = useAccount();

  const [subProposals, setSubProposals] = useState(null);
  const [subgraphError, setSubgraphError] = useState(false);
  const [manualId, setManualId] = useState("");
  const [manualList, setManualList] = useState([]);

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "getVotes",
    args: [address],
    query: { enabled: !!address },
  });

  // Pull proposals from subgraph
  useEffect(() => {
    fetchProposals(10)
      .then((d) => setSubProposals(d?.proposals ?? []))
      .catch(() => {
        setSubgraphError(true);
        setSubProposals([]);
      });
  }, []);

  const addManual = () => {
    const id = manualId.trim();
    if (!id) return;
    if (!manualList.includes(id)) setManualList((prev) => [id, ...prev]);
    setManualId("");
  };

  // Merge subgraph IDs + manual IDs, deduplicated
  const subIds = subProposals?.map((p) => p.proposalId) ?? [];
  return (
    <div className="page">
      <h1 className="page-title">Governance</h1>

      {/* ── Voting power info ──────────────────────────────────────────── */}
      {address && (
        <div className="card section-gap">
          <div className="grid-2">
            <div>
              <div className="card-title">Your Voting Power</div>
              <div className="card-value">{fmt(votingPower)} votes</div>
            </div>
            <div>
              <div className="card-title">Governor</div>
              <div className="text-sm mono text-muted mt-1">
                <div>Voting delay: 1 day</div>
                <div>Voting period: 1 week</div>
                <div>Quorum: 4% | Threshold: 1%</div>
                <div>Timelock delay: 2 days</div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Subgraph proposals ────────────────────────────────────────── */}
      <div className="section-gap">
        <div className="flex-between" style={{ marginBottom: "0.75rem" }}>
          <h2 style={{ fontSize: "1rem", fontWeight: 700 }}>Active Proposals</h2>
          <span className="text-sm text-muted">via The Graph</span>
        </div>

        {subgraphError && (
          <div className="card" style={{ marginBottom: "1rem" }}>
            <p className="text-sm text-muted">
              Subgraph unavailable — add proposal IDs manually below.
            </p>
          </div>
        )}

        {!subgraphError && subProposals === null && <span className="spinner" />}

        {subProposals?.length === 0 && !subgraphError && (
          <div className="card" style={{ marginBottom: "1rem" }}>
            <p className="text-sm text-muted">No proposals found in the subgraph.</p>
          </div>
        )}

        {/* Subgraph proposals with description */}
        {subProposals?.map((p) => (
          <div key={p.proposalId} style={{ marginBottom: "1rem" }}>
            <div
              className="text-sm text-muted mono"
              style={{ marginBottom: "0.25rem", paddingLeft: "0.25rem" }}
            >
              {p.description?.slice(0, 120) ?? "No description"}
            </div>
            <ProposalRow proposalId={p.proposalId} address={address} toast={toast} />
          </div>
        ))}
      </div>

      {/* ── Manual proposal lookup ────────────────────────────────────── */}
      <div className="card">
        <div className="card-title" style={{ marginBottom: "0.75rem" }}>
          Look up Proposal by ID
        </div>
        <div style={{ display: "flex", gap: "0.75rem", marginBottom: "1rem" }}>
          <input
            placeholder="Proposal ID (uint256)"
            value={manualId}
            onChange={(e) => setManualId(e.target.value)}
            style={{ flex: 1, fontFamily: "monospace" }}
          />
          <button className="btn-secondary" onClick={addManual}>
            Add
          </button>
        </div>

        {manualList.map((id) => (
          <div key={id}>
            <div className="text-sm text-muted mono" style={{ marginBottom: "0.25rem" }}>
              Manual: {id}
            </div>
            <ProposalRow proposalId={id} address={address} toast={toast} />
          </div>
        ))}

        {manualList.length === 0 && (
          <p className="text-sm text-muted">
            Enter a proposal ID to load its on-chain state and vote.
          </p>
        )}
      </div>
    </div>
  );
}
