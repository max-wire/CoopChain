import { BigInt, Bytes } from "@graphprotocol/graph-ts";

import {
  MemberRegistered as MemberRegisteredEvent,
  MemberDeactivated as MemberDeactivatedEvent,
} from "../generated/CoopVault/CoopVault";

import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
} from "../generated/Savings/Savings";

import {
  LoanCreated as LoanCreatedEvent,
  LoanPaymentDue as LoanPaymentDueEvent,
  LoanRepaid as LoanRepaidEvent,
  LoanDefaulted as LoanDefaultedEvent,
  LoanCancelled as LoanCancelledEvent,
} from "../generated/LoanEngine/LoanEngine";

import {
  InvestmentCreated as InvestmentCreatedEvent,
  InvestmentUpdated as InvestmentUpdatedEvent,
  InvestmentDeactivated as InvestmentDeactivatedEvent,
} from "../generated/InvestmentRegistry/InvestmentRegistry";

import {
  InvestmentPurchased as InvestmentPurchasedEvent,
  InvestmentRedeemed as InvestmentRedeemedEvent,
  PoolFunded as PoolFundedEvent,
  PoolWithdrawn as PoolWithdrawnEvent,
} from "../generated/InvestmentPool/InvestmentPool";

import {
  Transfer as TransferEvent,
  TokensMinted as TokensMintedEvent,
  TokensBurned as TokensBurnedEvent,
  MinterUpdated as MinterUpdatedEvent,
} from "../generated/templates/InvestmentToken/InvestmentToken";

import { InvestmentToken as InvestmentTokenTemplate } from "../generated/templates";

import {
  Member,
  SavingsTransaction,
  Loan,
  LoanPayment,
  LoanRepayment,
  Investment,
  InvestmentTransaction,
  PoolTransaction,
  InvestmentToken,
  InvestmentTokenHolder,
  InvestmentTokenTransfer,
  InvestmentTokenActivity,
  MinterUpdate,
} from "../generated/schema";

import { InvestmentToken as InvestmentTokenContract } from "../generated/templates/InvestmentToken/InvestmentToken";


// ============================================================
// HELPERS
// ============================================================

function getMemberId(wallet: Bytes): string {
  return wallet.toHexString().toLowerCase();
}


function getOrCreateMember(wallet: Bytes): Member {
  let id = getMemberId(wallet);

  let member = Member.load(id);

  if (member == null) {
    member = new Member(id);

    member.memberId = BigInt.zero();
    member.wallet = wallet;
    member.joinedAt = BigInt.zero();
    member.active = true;
    member.savingsBalance = BigInt.zero();

    member.save();
  }

  return member;
}


function getEventId(
  transactionHash: Bytes,
  logIndex: BigInt
): string {
  return (
    transactionHash.toHexString() +
    "-" +
    logIndex.toString()
  );
}


// ============================================================
// MEMBERS
// ============================================================

export function handleMemberRegistered(
  event: MemberRegisteredEvent
): void {
  let member = getOrCreateMember(event.params.wallet);

  member.memberId = event.params.memberId;
  member.wallet = event.params.wallet;
  member.joinedAt = event.params.joinedAt;
  member.active = true;

  member.save();
}


export function handleMemberDeactivated(
  event: MemberDeactivatedEvent
): void {
  let member = Member.load(
    getMemberId(event.params.wallet)
  );

  if (member == null) {
    return;
  }

  member.active = false;
  member.save();
}


// ============================================================
// SAVINGS
// ============================================================

export function handleDeposit(
  event: DepositEvent
): void {
  let member = getOrCreateMember(event.params.user);

  member.savingsBalance = event.params.newBalance;
  member.save();

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let transaction = new SavingsTransaction(id);

  transaction.member = member.id;
  transaction.user = event.params.user;
  transaction.amount = event.params.amount;
  transaction.newBalance = event.params.newBalance;
  transaction.type = "DEPOSIT";
  transaction.timestamp = event.block.timestamp;
  transaction.transactionHash = event.transaction.hash;

  transaction.save();
}


export function handleWithdraw(
  event: WithdrawEvent
): void {
  let member = getOrCreateMember(event.params.user);

  member.savingsBalance = event.params.newBalance;
  member.save();

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let transaction = new SavingsTransaction(id);

  transaction.member = member.id;
  transaction.user = event.params.user;
  transaction.amount = event.params.amount;
  transaction.newBalance = event.params.newBalance;
  transaction.type = "WITHDRAW";
  transaction.timestamp = event.block.timestamp;
  transaction.transactionHash = event.transaction.hash;

  transaction.save();
}


// ============================================================
// LOANS
// ============================================================

export function handleLoanCreated(
  event: LoanCreatedEvent
): void {
  let member = getOrCreateMember(
    event.params.borrower
  );

  let id = event.params.loanId.toString();

  let loan = Loan.load(id);

  if (loan == null) {
    loan = new Loan(id);
  }

  loan.loanId = event.params.loanId;
  loan.member = member.id;
  loan.borrower = event.params.borrower;
  loan.principal = event.params.principal;
  loan.interestRateBps =
    event.params.interestRateBps;
  loan.duration = event.params.duration;
  loan.monthlyPayment =
    event.params.monthlyPayment;
  loan.totalRepayment =
    event.params.totalRepayment;
  loan.amountRepaid = BigInt.zero();
  loan.nextDueDate =
    event.params.nextDueDate;
  loan.status = "ACTIVE";
  loan.createdAt =
    event.block.timestamp;
  loan.updatedAt =
    event.block.timestamp;

  loan.save();
}


export function handleLoanPaymentDue(
  event: LoanPaymentDueEvent
): void {
  let loan = Loan.load(
    event.params.loanId.toString()
  );

  if (loan == null) {
    return;
  }

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let payment = new LoanPayment(id);

  payment.loan = loan.id;
  payment.loanId = event.params.loanId;
  payment.dueDate = event.params.dueDate;
  payment.amount = event.params.amount;
  payment.timestamp =
    event.block.timestamp;
  payment.transactionHash =
    event.transaction.hash;

  payment.save();

  loan.updatedAt =
    event.block.timestamp;

  loan.save();
}


export function handleLoanRepaid(
  event: LoanRepaidEvent
): void {
  let loan = Loan.load(
    event.params.loanId.toString()
  );

  if (loan == null) {
    return;
  }

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let repayment = new LoanRepayment(id);

  repayment.loan = loan.id;
  repayment.loanId = event.params.loanId;
  repayment.borrower =
    event.params.borrower;
  repayment.amount =
    event.params.amount;
  repayment.timestamp =
    event.block.timestamp;
  repayment.transactionHash =
    event.transaction.hash;

  repayment.save();

  loan.amountRepaid =
    loan.amountRepaid.plus(
      event.params.amount
    );

  if (
    loan.amountRepaid.ge(
      loan.totalRepayment
    )
  ) {
    loan.status = "REPAID";
  } else {
    loan.status = "ACTIVE";
  }

  loan.updatedAt =
    event.block.timestamp;

  loan.save();
}


export function handleLoanDefaulted(
  event: LoanDefaultedEvent
): void {
  let loan = Loan.load(
    event.params.loanId.toString()
  );

  if (loan == null) {
    return;
  }

  loan.status = "DEFAULTED";
  loan.updatedAt =
    event.block.timestamp;

  loan.save();
}


export function handleLoanCancelled(
  event: LoanCancelledEvent
): void {
  let loan = Loan.load(
    event.params.loanId.toString()
  );

  if (loan == null) {
    return;
  }

  loan.status = "CANCELLED";
  loan.updatedAt =
    event.block.timestamp;

  loan.save();
}


// ============================================================
// INVESTMENTS
// ============================================================

export function handleInvestmentCreated(
  event: InvestmentCreatedEvent
): void {
  let id =
    event.params.investmentId.toString();

  let investment = new Investment(id);

  investment.investmentId =
    event.params.investmentId;

  investment.name =
    event.params.name;

  investment.symbol =
    event.params.symbol;

  investment.assetType =
    event.params.assetType;

  investment.issuer =
    event.params.issuer;

  investment.token =
    event.params.token;

  investment.price =
    event.params.price;

  investment.totalSupply =
    event.params.totalSupply;

  investment.active = true;

  investment.save();


  // ----------------------------------------------------------
  // Start indexing this investment's token.
  // ----------------------------------------------------------

  InvestmentTokenTemplate.create(
    event.params.token
  );


  // ----------------------------------------------------------
  // Create token metadata entity.
  // ----------------------------------------------------------

  let tokenAddress =
    event.params.token;

  let token =
    InvestmentTokenContract.bind(
      tokenAddress
    );

  let tokenEntity =
    new InvestmentToken(
      tokenAddress.toHexString()
    );

  tokenEntity.address =
    tokenAddress;

  tokenEntity.investment =
    investment.id;

  tokenEntity.investmentId =
    event.params.investmentId;

  tokenEntity.issuer =
    event.params.issuer;

  let maxSupplyResult =
    token.try_maxSupply();

  if (!maxSupplyResult.reverted) {
    tokenEntity.maxSupply =
      maxSupplyResult.value;
  } else {
    tokenEntity.maxSupply =
      event.params.totalSupply;
  }

  let minterResult =
    token.try_minter();

  if (!minterResult.reverted) {
    tokenEntity.minter =
      minterResult.value;
  } else {
    tokenEntity.minter =
      event.params.issuer;
  }

  tokenEntity.totalSupply =
    BigInt.zero();

  tokenEntity.save();
}


export function handleInvestmentUpdated(
  event: InvestmentUpdatedEvent
): void {
  let investment = Investment.load(
    event.params.investmentId.toString()
  );

  if (investment == null) {
    return;
  }

  investment.price =
    event.params.price;

  investment.totalSupply =
    event.params.totalSupply;

  investment.active =
    event.params.active;

  investment.save();
}


export function handleInvestmentDeactivated(
  event: InvestmentDeactivatedEvent
): void {
  let investment = Investment.load(
    event.params.investmentId.toString()
  );

  if (investment == null) {
    return;
  }

  investment.active = false;

  investment.save();
}


// ============================================================
// INVESTMENT POOL
// ============================================================

export function handleInvestmentPurchased(
  event: InvestmentPurchasedEvent
): void {
  let investment = Investment.load(
    event.params.investmentId.toString()
  );

  if (investment == null) {
    return;
  }

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let transaction =
    new InvestmentTransaction(id);

  transaction.investment =
    investment.id;

  transaction.investor =
    event.params.investor;

  transaction.usdcAmount =
    event.params.usdcAmount;

  transaction.tokenAmount =
    event.params.tokenAmount;

  transaction.type =
    "PURCHASE";

  transaction.timestamp =
    event.block.timestamp;

  transaction.transactionHash =
    event.transaction.hash;

  transaction.save();
}


export function handleInvestmentRedeemed(
  event: InvestmentRedeemedEvent
): void {
  let investment = Investment.load(
    event.params.investmentId.toString()
  );

  if (investment == null) {
    return;
  }

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let transaction =
    new InvestmentTransaction(id);

  transaction.investment =
    investment.id;

  transaction.investor =
    event.params.investor;

  transaction.usdcAmount =
    event.params.usdcAmount;

  transaction.tokenAmount =
    event.params.tokenAmount;

  transaction.type =
    "REDEEM";

  transaction.timestamp =
    event.block.timestamp;

  transaction.transactionHash =
    event.transaction.hash;

  transaction.save();
}


// ============================================================
// POOL
// ============================================================

export function handlePoolFunded(
  event: PoolFundedEvent
): void {
  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let transaction =
    new PoolTransaction(id);

  transaction.account =
    event.params.funder;

  transaction.amount =
    event.params.amount;

  transaction.type = "FUND";

  transaction.timestamp =
    event.block.timestamp;

  transaction.transactionHash =
    event.transaction.hash;

  transaction.save();
}


export function handlePoolWithdrawn(
  event: PoolWithdrawnEvent
): void {
  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let transaction =
    new PoolTransaction(id);

  transaction.account =
    event.params.recipient;

  transaction.amount =
    event.params.amount;

  transaction.type = "WITHDRAW";

  transaction.timestamp =
    event.block.timestamp;

  transaction.transactionHash =
    event.transaction.hash;

  transaction.save();
}


// ============================================================
// INVESTMENT TOKEN
// ============================================================

function getTokenHolderId(
  token: Bytes,
  account: Bytes
): string {
  return (
    token.toHexString().toLowerCase() +
    "-" +
    account.toHexString().toLowerCase()
  );
}


function getInvestmentToken(
  tokenAddress: Bytes
): InvestmentToken | null {
  return InvestmentToken.load(
    tokenAddress.toHexString()
  );
}


function getOrCreateTokenHolder(
  token: InvestmentToken,
  account: Bytes
): InvestmentTokenHolder {
  let id = getTokenHolderId(
    token.address,
    account
  );

  let holder =
    InvestmentTokenHolder.load(id);

  if (holder == null) {
    holder =
      new InvestmentTokenHolder(id);

    holder.token = token.id;
    holder.account = account;
    holder.balance = BigInt.zero();
    holder.updatedAt = BigInt.zero();
  }

  return holder;
}


export function handleInvestmentTokenTransfer(
  event: TransferEvent
): void {
  let token =
    getInvestmentToken(
      event.address
    );

  if (token == null) {
    return;
  }

  let investment =
    Investment.load(
      token.investmentId.toString()
    );

  if (investment == null) {
    return;
  }


  // ----------------------------------------------------------
  // Update sender balance.
  //
  // For minting, from == address(0), so there is no sender
  // balance to update.
  // ----------------------------------------------------------

  if (
    event.params.from !=
    Bytes.fromHexString(
      "0x0000000000000000000000000000000000000000"
    )
  ) {
    let sender =
      getOrCreateTokenHolder(
        token,
        event.params.from
      );

    if (
      sender.balance.ge(
        event.params.value
      )
    ) {
      sender.balance =
        sender.balance.minus(
          event.params.value
        );
    } else {
      sender.balance =
        BigInt.zero();
    }

    sender.updatedAt =
      event.block.timestamp;

    sender.save();
  }


  // ----------------------------------------------------------
  // Update receiver balance.
  //
  // For burning, to == address(0), so there is no receiver
  // balance to update.
  // ----------------------------------------------------------

  if (
    event.params.to !=
    Bytes.fromHexString(
      "0x0000000000000000000000000000000000000000"
    )
  ) {
    let receiver =
      getOrCreateTokenHolder(
        token,
        event.params.to
      );

    receiver.balance =
      receiver.balance.plus(
        event.params.value
      );

    receiver.updatedAt =
      event.block.timestamp;

    receiver.save();
  }


  // ----------------------------------------------------------
  // Update total supply.
  // ----------------------------------------------------------

  if (
    event.params.from ==
    Bytes.fromHexString(
      "0x0000000000000000000000000000000000000000"
    )
  ) {
    token.totalSupply =
      token.totalSupply.plus(
        event.params.value
      );
  }

  if (
    event.params.to ==
    Bytes.fromHexString(
      "0x0000000000000000000000000000000000000000"
    )
  ) {
    if (
      token.totalSupply.ge(
        event.params.value
      )
    ) {
      token.totalSupply =
        token.totalSupply.minus(
          event.params.value
        );
    }
  }

  token.save();


  // ----------------------------------------------------------
  // Store transfer.
  // ----------------------------------------------------------

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let transfer =
    new InvestmentTokenTransfer(id);

  transfer.token =
    token.id;

  transfer.investment =
    investment.id;

  transfer.from =
    event.params.from;

  transfer.to =
    event.params.to;

  transfer.amount =
    event.params.value;

  transfer.timestamp =
    event.block.timestamp;

  transfer.transactionHash =
    event.transaction.hash;

  transfer.save();
}


// ============================================================
// TOKEN MINT
// ============================================================

export function handleTokensMinted(
  event: TokensMintedEvent
): void {
  let token =
    getInvestmentToken(
      event.address
    );

  if (token == null) {
    return;
  }

  let investment =
    Investment.load(
      token.investmentId.toString()
    );

  if (investment == null) {
    return;
  }

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let activity =
    new InvestmentTokenActivity(id);

  activity.token =
    token.id;

  activity.investment =
    investment.id;

  activity.account =
    event.params.account;

  activity.amount =
    event.params.amount;

  activity.type =
    "MINT";

  activity.timestamp =
    event.block.timestamp;

  activity.transactionHash =
    event.transaction.hash;

  activity.save();
}


// ============================================================
// TOKEN BURN
// ============================================================

export function handleTokensBurned(
  event: TokensBurnedEvent
): void {
  let token =
    getInvestmentToken(
      event.address
    );

  if (token == null) {
    return;
  }

  let investment =
    Investment.load(
      token.investmentId.toString()
    );

  if (investment == null) {
    return;
  }

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let activity =
    new InvestmentTokenActivity(id);

  activity.token =
    token.id;

  activity.investment =
    investment.id;

  activity.account =
    event.params.account;

  activity.amount =
    event.params.amount;

  activity.type =
    "BURN";

  activity.timestamp =
    event.block.timestamp;

  activity.transactionHash =
    event.transaction.hash;

  activity.save();
}


// ============================================================
// MINTER UPDATE
// ============================================================

export function handleMinterUpdated(
  event: MinterUpdatedEvent
): void {
  let token =
    getInvestmentToken(
      event.address
    );

  if (token == null) {
    return;
  }

  token.minter =
    event.params.newMinter;

  token.save();

  let id = getEventId(
    event.transaction.hash,
    event.logIndex
  );

  let update =
    new MinterUpdate(id);

  update.token =
    token.id;

  update.previousMinter =
    event.params.previousMinter;

  update.newMinter =
    event.params.newMinter;

  update.timestamp =
    event.block.timestamp;

  update.transactionHash =
    event.transaction.hash;

  update.save();
}