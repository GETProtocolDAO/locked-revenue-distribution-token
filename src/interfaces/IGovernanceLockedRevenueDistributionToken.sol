// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

interface IGovernanceLockedRevenueDistributionToken {
    /**
     * @notice        Represents a voting checkpoin, packed into a single word.
     * @custom:member fromBlock Block number after which the checkpoint applies.
     * @custom:member shares    Amount of shares held & delegated to calculate point-int-time votes.
     * @custom:member votes     Number of votes available, representing the amount of assets for delegated shares.
     */
    struct Checkpoint {
        uint32 fromBlock;
        uint112 votes;
        uint112 shares;
    }

    /*░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░░░░                              Events                               ░░░░
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░*/

    /**
     * @notice Emitted when an account changes their delegate.
     * @param  delegator_    Account that has changed delegate.
     * @param  fromDelegate_ Previous delegate.
     * @param  toDelegate_   New delegate.
     */
    event DelegateChanged(address indexed delegator_, address indexed fromDelegate_, address indexed toDelegate_);

    /**
     * @notice Emitted when a token transfer or delegate change results in changes to a delegate's number of votes.
     * @param  delegate_        Delegate that has received delegated balance change.
     * @param  previousBalance_ Previous delegated balance.
     * @param  newBalance_      New delegated balance.
     */
    event DelegateVotesChanged(address indexed delegate_, uint256 previousBalance_, uint256 newBalance_);

    /*░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░░░░                          State Variables                          ░░░░
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░*/

    /**
     * @notice Returns the delegate typehash, used in `delegateBySig`.
     * @return delegateTypehash_ The delegate typehash.
     */
    function DELEGATE_TYPEHASH() external view returns (bytes32 delegateTypehash_);

    /**
     * @notice Get the `pos`-th checkpoint for `account`.
     * @dev    Unused in Compound governance specification, exposes underlying Checkpoint struct.
     * @param  account_  Account that holds checkpoint.
     * @param  pos_      Index/position of the checkpoint.
     * @return fromBlock Block in which the checkpoint is valid from.
     * @return votes     Total amount of underlying assets (votes) derived from shares.
     * @return shares    Total amount of shares within the checkpoint.
     */
    function userCheckpoints(address account_, uint256 pos_)
        external
        view
        returns (uint32 fromBlock, uint112 votes, uint112 shares);

    /*░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░░░░                         Public Functions                          ░░░░
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░*/

    /**
     * @notice Delegates votes from the sender to `delegatee`.
     * @dev    Shares are delegated upon mint and transfer and removed upon burn.
     * @param  delegatee_ Account to delegate votes to.
     */
    function delegate(address delegatee_) external;

    /**
     * @notice Delegates votes from signer to `delegatee`.
     * @param  delegatee_ Account to delegate votes to.
     * @param  nonce_     Nonce of next signature transaction, expected to be equal to `nonces(signer)`.
     * @param  deadline_  Deadline after which the permit is invalid.
     * @param  v_         ECDSA signature v component.
     * @param  r_         ECDSA signature r component.
     * @param  s_         ECDSA signature s component.
     */
    function delegateBySig(address delegatee_, uint256 nonce_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_)
        external;

    /*░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░░░░                          View Functions                           ░░░░
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░*/

    /**
     * @notice Get the Compound-compatible `pos`-th checkpoint for `account`.
     * @dev    Maintains Compound `checkpoints` compatibility by returning votes as a uint96 and omitting shares.
     * @param  account_   Account that holds checkpoint.
     * @param  pos_       Index/position of the checkpoint.
     * @return fromBlock_ Block in which the checkpoint is valid from.
     * @return votes_     Total amount of underlying assets (votes) derived from shares.
     */
    function checkpoints(address account_, uint32 pos_) external view returns (uint32 fromBlock_, uint96 votes_);

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account_) external view returns (uint32);

    /**
     * @notice Returns the current amount of votes that `account` has.
     * @dev    The delegated balance is denominated in the amount of shares delegated to an account, but voting power
     * is measured in assets. A conversion is done using the delegated shares to get the current assets.
     * @param  account_ Address of account to get votes for.
     * @return votes_   Amount of voting power as the number of assets for delegated shares.
     */
    function getVotes(address account_) external view returns (uint256 votes_);

    /**
     * @notice Comp version of the `getVotes` accessor, with `uint96` return type.
     * @param  account_ Address of account to get votes for.
     * @return votes_   Amount of voting power as the number of assets for delegated shares.
     */
    function getCurrentVotes(address account_) external view returns (uint96 votes_);

    /**
     * @notice Returns the amount of votes that `account` had at the end of a past block (`blockNumber`).
     * @param  account_     Address of account to get votes for.
     * @param  blockNumber_ Voting power at block.
     * @return votes_       Amount of voting power as the number of assets for delegated shares.
     */
    function getPastVotes(address account_, uint256 blockNumber_) external view returns (uint256 votes_);

    /**
     * @notice Comp version of the `getPastVotes` accessor, with `uint96` return type.
     * @param  account_     Address of account to get votes for.
     * @param  blockNumber_ Voting power at block.
     * @return votes_       Amount of voting power as the number of assets for delegated shares.
     */
    function getPriorVotes(address account_, uint256 blockNumber_) external view returns (uint96 votes_);

    /**
     * @notice Returns the total supply of shares available at the end of a past block (`blockNumber`).
     * @param  blockNumber_ Block number to check for total supply.
     * @return totalSupply_ Total supply of shares.
     */
    function getPastTotalSupply(uint256 blockNumber_) external view returns (uint256 totalSupply_);
}
