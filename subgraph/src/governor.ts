import { BigInt } from "@graphprotocol/graph-ts";
import {
  ProposalCanceled,
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  VoteCast,
} from "../generated/GameFiGovernor/GameFiGovernor";
import { Proposal, Vote } from "../generated/schema";

function proposalEntityId(proposalId: BigInt): string {
  return proposalId.toString();
}

export function handleProposalCreated(event: ProposalCreated): void {
  let id = proposalEntityId(event.params.proposalId);
  let proposal = new Proposal(id);

  proposal.proposalId = event.params.proposalId;
  proposal.proposer = event.params.proposer;
  proposal.description = event.params.description;
  proposal.status = "Pending";
  proposal.forVotes = BigInt.fromI32(0);
  proposal.againstVotes = BigInt.fromI32(0);
  proposal.abstainVotes = BigInt.fromI32(0);
  proposal.voteStart = event.params.voteStart;
  proposal.voteEnd = event.params.voteEnd;
  proposal.createdAt = event.block.timestamp;

  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let proposal = Proposal.load(proposalEntityId(event.params.proposalId));
  if (proposal == null) {
    return;
  }

  if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight);
  } else if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight);
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight);
  }

  proposal.status = "Active";
  proposal.save();

  let voteId = event.transaction.hash.toHexString().concat("-").concat(event.logIndex.toString());
  let vote = new Vote(voteId);
  vote.proposal = proposal.id;
  vote.voter = event.params.voter;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.timestamp = event.block.timestamp;
  vote.txHash = event.transaction.hash;
  vote.save();
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = Proposal.load(proposalEntityId(event.params.proposalId));
  if (proposal == null) {
    return;
  }

  proposal.status = "Queued";
  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(proposalEntityId(event.params.proposalId));
  if (proposal == null) {
    return;
  }

  proposal.status = "Executed";
  proposal.executedAt = event.block.timestamp;
  proposal.save();
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let proposal = Proposal.load(proposalEntityId(event.params.proposalId));
  if (proposal == null) {
    return;
  }

  proposal.status = "Canceled";
  proposal.canceledAt = event.block.timestamp;
  proposal.save();
}
