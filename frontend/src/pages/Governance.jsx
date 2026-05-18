import { useEffect, useState } from "react";
import { useAccount, useReadContract, useWaitForTransactionReceipt } from "wagmi";
import { decodeEventLog, encodeFunctionData } from "viem";
import { useWriteContract } from "../hooks/useWrite";
import {
  ADDRESSES,
  GOVERNANCE_TOKEN_ABI,
  GOVERNOR_ABI,
  PROPOSAL_STATE,
  PROPOSAL_STATE_COLOR,
  isConfiguredAddress,
} from "../config/contracts";
import { fetchProposals } from "../config/subgraph";
import ConfigNotice from "../components/ConfigNotice";
import { useTransactionToast } from "../hooks/useTransactionToast";
import { formatToken } from "../utils/format";

function StateBadge({ state }) {
  const label = PROPOSAL_STATE[state] || "Unknown";
  const color = PROPOSAL_STATE_COLOR[label] || "#6b7280";

  return (
    <span
      className="badge"
      style={{
        background: `${color}22`,
        color,
        border: `1px solid ${color}55`,
      }}
    >
      {label}
    </span>
  );
}

function ProposalCard({ proposalId, address, toast }) {
  const [support, setSupport] = useState(1);
  const idBig = BigInt(proposalId);

  const { data: state } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "state",
    args: [idBig],
    query: { enabled: isConfiguredAddress(ADDRESSES.GOVERNOR) },
  });

  const { data: votes } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "proposalVotes",
    args: [idBig],
    query: { enabled: isConfiguredAddress(ADDRESSES.GOVERNOR) },
  });

  const { data: deadline } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "proposalDeadline",
    args: [idBig],
    query: { enabled: isConfiguredAddress(ADDRESSES.GOVERNOR) },
  });

  const { data: hasVoted } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "hasVoted",
    args: [idBig, address],
    query: { enabled: !!address && isConfiguredAddress(ADDRESSES.GOVERNOR) },
  });

  const { writeContract, data: voteHash, isPending, error } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: voteHash });

  useTransactionToast(toast, isSuccess, error, "Vote submitted.");

  const handleVote = () => {
    writeContract({
      address: ADDRESSES.GOVERNOR,
      abi: GOVERNOR_ABI,
      functionName: "castVote",
      args: [idBig, support],
    });
  };

  return (
    <div className="card" style={{ marginBottom: "1rem" }}>
      <div className="flex-between" style={{ marginBottom: "0.75rem" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <span className="mono text-sm text-muted">#{proposalId}</span>
          {state !== undefined && <StateBadge state={state} />}
        </div>
        <span className="text-sm text-muted">Deadline block: {deadline?.toString() || "--"}</span>
      </div>

      {votes && (
        <div style={{ marginBottom: "0.75rem" }}>
          <div className="stat-row">
            <span className="label">For</span>
            <span className="value">{formatToken(votes[1])}</span>
          </div>
          <div className="stat-row">
            <span className="label">Against</span>
            <span className="value">{formatToken(votes[0])}</span>
          </div>
          <div className="stat-row">
            <span className="label">Abstain</span>
            <span className="value">{formatToken(votes[2])}</span>
          </div>
        </div>
      )}

      {state === 1 && (
        <div style={{ display: "flex", gap: "0.75rem", alignItems: "center", flexWrap: "wrap" }}>
          <select
            value={support}
            onChange={(event) => setSupport(Number(event.target.value))}
            style={{ maxWidth: "180px" }}
          >
            <option value={1}>For</option>
            <option value={0}>Against</option>
            <option value={2}>Abstain</option>
          </select>
          <button
            className="btn-primary"
            disabled={!address || hasVoted || isPending || confirming}
            onClick={handleVote}
          >
            {isPending || confirming ? "Voting..." : hasVoted ? "Already voted" : "Cast vote"}
          </button>
        </div>
      )}
    </div>
  );
}

export default function Governance({ toast }) {
  const { address } = useAccount();
  const [proposals, setProposals] = useState(null);
  const [subgraphError, setSubgraphError] = useState(false);
  const [manualProposalId, setManualProposalId] = useState("");
  const [manualIds, setManualIds] = useState([]);
  const [proposeDesc, setProposeDesc] = useState("");

  const configured = {
    governor: isConfiguredAddress(ADDRESSES.GOVERNOR),
    governanceToken: isConfiguredAddress(ADDRESSES.GOVERNANCE_TOKEN),
  };

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.GOVERNANCE_TOKEN,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "getVotes",
    args: [address],
    query: { enabled: !!address && configured.governanceToken },
  });

  const { data: votingDelay } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "votingDelay",
    query: { enabled: configured.governor },
  });

  const { data: votingPeriod } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "votingPeriod",
    query: { enabled: configured.governor },
  });

  const { data: proposalThreshold } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "proposalThreshold",
    query: { enabled: configured.governor },
  });

  const { data: quorumNumerator } = useReadContract({
    address: ADDRESSES.GOVERNOR,
    abi: GOVERNOR_ABI,
    functionName: "quorumNumerator",
    query: { enabled: configured.governor },
  });

  const {
    writeContract: proposeWrite,
    data: proposeHash,
    isPending: proposePending,
    error: proposeError,
  } = useWriteContract();
  const {
    isLoading: proposeConfirming,
    isSuccess: proposeSuccess,
    data: proposeReceipt,
  } = useWaitForTransactionReceipt({ hash: proposeHash });
  useTransactionToast(toast, proposeSuccess, proposeError, "Proposal created.");

  useEffect(() => {
    if (!proposeSuccess || !proposeReceipt) return;
    for (const log of proposeReceipt.logs) {
      try {
        const decoded = decodeEventLog({ abi: GOVERNOR_ABI, data: log.data, topics: log.topics });
        if (decoded.eventName === "ProposalCreated") {
          const id = decoded.args.proposalId.toString();
          setManualIds((prev) => (prev.includes(id) ? prev : [id, ...prev]));
          toast?.success(`Proposal ID added to lookup: ${id.slice(0, 12)}…`);
          break;
        }
      } catch {}
    }
  }, [proposeSuccess, proposeReceipt]);

  const handlePropose = () => {
    if (!proposeDesc.trim()) {
      toast?.error("Enter a description.");
      return;
    }
    if (!address) {
      toast?.error("Connect wallet.");
      return;
    }
    const calldata = encodeFunctionData({
      abi: GOVERNANCE_TOKEN_ABI,
      functionName: "delegate",
      args: [address],
    });
    proposeWrite({
      address: ADDRESSES.GOVERNOR,
      abi: GOVERNOR_ABI,
      functionName: "propose",
      args: [[ADDRESSES.GOVERNANCE_TOKEN], [0n], [calldata], proposeDesc],
    });
  };

  useEffect(() => {
    fetchProposals(10)
      .then((data) => setProposals(data?.proposals ?? []))
      .catch(() => {
        setSubgraphError(true);
        setProposals([]);
      });
  }, []);

  const addManualId = () => {
    const trimmed = manualProposalId.trim();
    if (!trimmed) return;
    if (!manualIds.includes(trimmed)) setManualIds((prev) => [trimmed, ...prev]);
    setManualProposalId("");
  };

  return (
    <div className="page">
      <h1 className="page-title">DAO Governance</h1>

      <ConfigNotice
        title="Frontend contract config"
        lines={[
          ...(!configured.governor ? ["Set VITE_GOVERNOR_ADDRESS."] : []),
          ...(!configured.governanceToken ? ["Set VITE_GOVERNANCE_TOKEN_ADDRESS."] : []),
        ]}
      />

      <div className="card section-gap">
        <div className="grid-2">
          <div>
            <div className="card-title">Your voting power</div>
            <div className="card-value">
              {address ? formatToken(votingPower) : "Connect wallet"}
            </div>
          </div>
          <div>
            <div className="card-title">Governor parameters</div>
            <div className="text-sm text-muted mt-1">
              <div>Voting delay: {votingDelay?.toString() || "--"} blocks</div>
              <div>Voting period: {votingPeriod?.toString() || "--"} blocks</div>
              <div>Proposal threshold: {formatToken(proposalThreshold)} tokens</div>
              <div>Quorum numerator: {quorumNumerator?.toString() || "--"}%</div>
            </div>
          </div>
        </div>
      </div>

      {address && configured.governor && (
        <div className="card section-gap">
          <div className="card-title">Create proposal</div>
          <p className="text-sm text-muted" style={{ marginBottom: "0.75rem" }}>
            Creates a test proposal (action: re-delegate gGAME votes to self). Requires voting power
            ≥ proposal threshold.
          </p>
          <input
            value={proposeDesc}
            onChange={(event) => setProposeDesc(event.target.value)}
            placeholder="Proposal description"
            style={{ width: "100%", marginBottom: "0.75rem" }}
          />
          <button
            className="btn-primary"
            disabled={proposePending || proposeConfirming}
            onClick={handlePropose}
          >
            {proposePending || proposeConfirming ? "Submitting..." : "Create proposal"}
          </button>
        </div>
      )}

      <div className="section-gap">
        <div className="flex-between" style={{ marginBottom: "0.75rem" }}>
          <h2 style={{ fontSize: "1rem", fontWeight: 700 }}>Indexed proposals</h2>
          <span className="text-sm text-muted">via The Graph</span>
        </div>

        {subgraphError && (
          <div className="card" style={{ marginBottom: "1rem" }}>
            <p className="text-sm text-muted">
              Subgraph unavailable. Use manual proposal lookup below.
            </p>
          </div>
        )}

        {!subgraphError && proposals === null && <span className="spinner" />}

        {!subgraphError &&
          proposals?.map((proposal) => (
            <div key={proposal.id}>
              <div
                className="text-sm text-muted"
                style={{ marginBottom: "0.35rem", paddingLeft: "0.25rem" }}
              >
                {proposal.description || "No description"}
              </div>
              <ProposalCard proposalId={proposal.proposalId} address={address} toast={toast} />
            </div>
          ))}
      </div>

      <div className="card">
        <div className="card-title" style={{ marginBottom: "0.75rem" }}>
          Manual proposal lookup
        </div>
        <div style={{ display: "flex", gap: "0.75rem", marginBottom: "1rem" }}>
          <input
            value={manualProposalId}
            onChange={(event) => setManualProposalId(event.target.value)}
            placeholder="Proposal ID"
            style={{ flex: 1 }}
          />
          <button className="btn-secondary" onClick={addManualId}>
            Add
          </button>
        </div>

        {manualIds.length === 0 && (
          <p className="text-sm text-muted">
            Enter a proposal ID to inspect and vote on it directly from chain state.
          </p>
        )}

        {manualIds.map((proposalId) => (
          <ProposalCard key={proposalId} proposalId={proposalId} address={address} toast={toast} />
        ))}
      </div>
    </div>
  );
}
