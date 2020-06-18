pragma solidity ^0.4.24;

import "./CrowdsaleKYC.sol";

/**
 * @title CappedCrowdsaleKYC
 * @dev Extension of Crowsdale with a max amount of funds raised
 */
contract TokenCappedCrowdsaleKYC is CrowdsaleKYC {
    using SafeMath for uint256;

    // The maximum token cap, should be initialized in derived contract
    uint256 public tokenCap;

    // Overriding Crowdsale#hasEnded to add tokenCap logic
    // @return true if crowdsale event has ended
    function hasEnded() public view returns (bool) {
        bool capReached = soldTokens >= tokenCap;
        return super.hasEnded() || capReached;
    }

    // Overriding Crowdsale#isValidPurchase to add extra cap logic
    // @return true if investors can buy at the moment
    function isValidPurchase(address beneficiary) internal view returns (bool isValid) {
        uint256 tokenAmount = calculateTokens(msg.value);
        bool withinCap = soldTokens.add(tokenAmount) <= tokenCap;
        return withinCap && super.isValidPurchase(beneficiary);
    }
}
