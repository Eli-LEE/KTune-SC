pragma solidity ^0.4.24;

import "./WhitelistableConstraints.sol";

/**
 * @title Whitelistable
 * @dev Base contract implementing a whitelist to keep track of investors.
 * The construction parameters allow for both whitelisted and non-whitelisted contracts:
 * 1) maxWhitelistLength = 0 and whitelistThresholdBalance > 0: whitelist disabled
 * 2) maxWhitelistLength > 0 and whitelistThresholdBalance = 0: whitelist enabled, full whitelisting
 * 3) maxWhitelistLength > 0 and whitelistThresholdBalance > 0: whitelist enabled, partial whitelisting
 */
contract Whitelistable is WhitelistableConstraints {

    event LogMaxWhitelistLengthChanged(address indexed caller, uint256 indexed maxWhitelistLength);
    event LogWhitelistThresholdBalanceChanged(address indexed caller, uint256 indexed whitelistThresholdBalance);
    event LogWhitelistAddressAdded(address indexed caller, address indexed subscriber);
    event LogWhitelistAddressRemoved(address indexed caller, address indexed subscriber);

    mapping (address => bool) public whitelist;

    uint256 public whitelistLength;

    uint256 public maxWhitelistLength;

    uint256 public whitelistThresholdBalance;

    constructor(uint256 _maxWhitelistLength, uint256 _whitelistThresholdBalance) internal {
        require(isAllowedWhitelist(_maxWhitelistLength, _whitelistThresholdBalance), "parameters not allowed");

        maxWhitelistLength = _maxWhitelistLength;
        whitelistThresholdBalance = _whitelistThresholdBalance;
    }

    /**
     * @return true if whitelist is currently enabled, false otherwise
     */
    function isWhitelistEnabled() public view returns(bool isReallyWhitelistEnabled) {
        return maxWhitelistLength > 0;
    }

    /**
     * @return true if subscriber is whitelisted, false otherwise
     */
    function isWhitelisted(address _subscriber) public view returns(bool isReallyWhitelisted) {
        return whitelist[_subscriber];
    }

    function setMaxWhitelistLengthInternal(uint256 _maxWhitelistLength) internal {
        require(isAllowedWhitelist(_maxWhitelistLength, whitelistThresholdBalance),
            "_maxWhitelistLength not allowed");
        require(_maxWhitelistLength != maxWhitelistLength, "_maxWhitelistLength equal to current one");

        maxWhitelistLength = _maxWhitelistLength;

        emit LogMaxWhitelistLengthChanged(msg.sender, maxWhitelistLength);
    }

    function setWhitelistThresholdBalanceInternal(uint256 _whitelistThresholdBalance) internal {
        require(isAllowedWhitelist(maxWhitelistLength, _whitelistThresholdBalance),
            "_whitelistThresholdBalance not allowed");
        require(whitelistLength == 0 || _whitelistThresholdBalance > whitelistThresholdBalance,
            "_whitelistThresholdBalance not greater than current one");

        whitelistThresholdBalance = _whitelistThresholdBalance;

        emit LogWhitelistThresholdBalanceChanged(msg.sender, _whitelistThresholdBalance);
    }

    function addToWhitelistInternal(address _subscriber) internal {
        require(_subscriber != address(0), "_subscriber is zero");
        require(!whitelist[_subscriber], "already whitelisted");
        require(whitelistLength < maxWhitelistLength, "max whitelist length reached");

        whitelistLength++;

        whitelist[_subscriber] = true;

        emit LogWhitelistAddressAdded(msg.sender, _subscriber);
    }

    function removeFromWhitelistInternal(address _subscriber, uint256 _balance) internal {
        require(_subscriber != address(0), "_subscriber is zero");
        require(whitelist[_subscriber], "not whitelisted");
        require(_balance <= whitelistThresholdBalance, "_balance greater than whitelist threshold");

        assert(whitelistLength > 0);

        whitelistLength--;

        whitelist[_subscriber] = false;

        emit LogWhitelistAddressRemoved(msg.sender, _subscriber);
    }

    /**
     * @param _subscriber The subscriber for which the balance check is required.
     * @param _balance The balance value to check for allowance.
     * @return true if the balance is allowed for the subscriber, false otherwise
     */
    function isAllowedBalance(address _subscriber, uint256 _balance) public view returns(bool isReallyAllowed) {
        return !isWhitelistEnabled() || _balance <= whitelistThresholdBalance || whitelist[_subscriber];
    }
}
