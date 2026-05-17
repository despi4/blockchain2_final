import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  ProposalCreated,
  VoteCast,
  ProposalQueued,
  ProposalExecuted,
  ProposalCanceled,
} from "../generated/GameFiGovernor/GameFiGovernor";
import { Proposal, Vote } from "../generated/schema";

export function handleProposalCreated(event: ProposalCreated): void {
  let proposal = new Proposal(Bytes.fromBigInt(event.params.proposalId));
  proposal.proposalId   = event.params.proposalId;
  proposal.proposer     = event.params.proposer;
  proposal.description  = event.params.description;
  proposal.status       = "Pending";
  proposal.forVotes     = BigInt.zero();
  proposal.againstVotes = BigInt.zero();
  proposal.abstainVotes = BigInt.zero();
  proposal.voteStart    = event.params.voteStart;
  proposal.voteEnd      = event.params.voteEnd;
  proposal.createdAt    = event.block.timestamp;
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let proposal = Proposal.load(Bytes.fromBigInt(event.params.proposalId));
  if (!proposal) return;

  // Update aggregate vote counts
  if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight);
  } else if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight);
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight);
  }
  proposal.status = "Active";
  proposal.save();

  // Create individual vote record
  let voteId = event.transaction.hash.concatI32(event.logIndex.toI32());
  let vote      = new Vote(voteId);
  vote.proposal  = proposal.id;
  vote.voter     = event.params.voter;
  vote.support   = event.params.support;
  vote.weight    = event.params.weight;
  vote.reason    = event.params.reason;
  vote.timestamp = event.block.timestamp;
  vote.txHash    = event.transaction.hash;
  vote.save();
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = Proposal.load(Bytes.fromBigInt(event.params.proposalId));
  if (!proposal) return;
  proposal.status = "Queued";
  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(Bytes.fromBigInt(event.params.proposalId));
  if (!proposal) return;
  proposal.status     = "Executed";
  proposal.executedAt = event.block.timestamp;
  proposal.save();
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let proposal = Proposal.load(Bytes.fromBigInt(event.params.proposalId));
  if (!proposal) return;
  proposal.status     = "Canceled";
  proposal.canceledAt = event.block.timestamp;
  proposal.save();
}
