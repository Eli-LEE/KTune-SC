pragma solidity ^0.4.24;

import "../DeclarContract/Pausable.sol";
import "../DeclarContract/Whitelistable.sol";
import "../DeclarContract/KYCBase.sol";
import "../DeclarContract/MintableToken.sol";
import "../Library/SafeMath.sol";
import "../Library/AddressUtils.sol";

/**
 * @title CrowdsaleKYC
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end block, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract CrowdsaleKYC is Pausable, Whitelistable, KYCBase {
    using AddressUtils for address;
    using SafeMath for uint256;

    event LogStartBlockChanged(uint256 indexed startBlock);
    event LogEndBlockChanged(uint256 indexed endBlock);
    event LogMinDepositChanged(uint256 indexed minDeposit);
    event LogTokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 indexed amount, uint256 tokenAmount);
    event AddedSenderAllowed(address semder);
    event RemovedSenderAllowed(address semder);

    // The token being sold
    MintableToken public token;

    // The start and end block where investments are allowed (both inclusive)
    uint256 public startBlock;
    uint256 public endBlock;

    // How many token units a buyer gets per wei
    uint256 public rate;

    // Amount of raised money in wei
    uint256 public raisedFunds;

    // Amount of tokens already sold
    uint256 public soldTokens;

    // Balances in wei deposited by each subscriber
    mapping (address => uint256) public balanceOf;

    // The minimum balance for each subscriber in wei
    uint256 public minDeposit;

    // Senders allowed for buyTokensFor function
    mapping (address => bool) public isAllowedSender;

    modifier beforeStart() {
        require(block.number < startBlock, "already started");
        _;
    }

    modifier beforeEnd() {
        require(block.number <= endBlock, "already ended");
        _;
    }

    constructor(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rate,
        uint256 _minDeposit,
        uint256 maxWhitelistLength,
        uint256 whitelistThreshold,
        address[] memory kycSigner
    )
    Whitelistable(maxWhitelistLength, whitelistThreshold)
    KYCBase(kycSigner) internal
    {
        require(_startBlock >= block.number, "_startBlock is lower than current block.number");
        require(_endBlock >= _startBlock, "_endBlock is lower than _startBlock");
        require(_rate > 0, "_rate is zero");
        require(_minDeposit > 0, "_minDeposit is zero");

        startBlock = _startBlock;
        endBlock = _endBlock;
        rate = _rate;
        minDeposit = _minDeposit;
    }

    //override KYCBase.senderAllowedFor
    function senderAllowedFor(address buyer) internal view returns(bool)
    {
        //revert(appendStr("override KYCBase.senderAllowedFor", toAsciiString(msg.sender), isAllowedSender[buyer]));
        require(buyer == msg.sender, "Buyer address not equal action address");
        return isAllowedSender[msg.sender] == true;
    }

    function addSenderAllowed(address _sender) external onlyOwner {
        isAllowedSender[_sender] = true;
        emit AddedSenderAllowed(_sender);
    }

    function removeSenderAllowed(address _sender) external onlyOwner {
        delete isAllowedSender[_sender];
        emit RemovedSenderAllowed(_sender);
    }

    /*
    * @return true if crowdsale event has started
    */
    function hasStarted() public view returns (bool started) {
        return block.number >= startBlock;
    }

    /*
    * @return true if crowdsale event has ended
    */
    function hasEnded() public view returns (bool ended) {
        return block.number > endBlock;
    }

    /**
     * Change the crowdsale start block number.
     * @param _startBlock The new start block
     */
    function setStartBlock(uint256 _startBlock) external onlyOwner beforeStart {
        require(_startBlock >= block.number, "_startBlock < current block");
        require(_startBlock <= endBlock, "_startBlock > endBlock");
        require(_startBlock != startBlock, "_startBlock == startBlock");

        startBlock = _startBlock;

        emit LogStartBlockChanged(_startBlock);
    }

    /**
     * Change the crowdsale end block number.
     * @param _endBlock The new end block
     */
    function setEndBlock(uint256 _endBlock) external onlyOwner beforeEnd {
        require(_endBlock >= block.number, "_endBlock < current block");
        require(_endBlock >= startBlock, "_endBlock < startBlock");
        require(_endBlock != endBlock, "_endBlock == endBlock");

        endBlock = _endBlock;

        emit LogEndBlockChanged(_endBlock);
    }

    /**
     * Change the minimum deposit for each subscriber. New value shall be lower than previous.
     * @param _minDeposit The minimum deposit for each subscriber, expressed in wei
     */
    function setMinDeposit(uint256 _minDeposit) external onlyOwner beforeEnd {
        require(0 < _minDeposit && _minDeposit < minDeposit, "_minDeposit is not in [0, minDeposit]");

        minDeposit = _minDeposit;

        emit LogMinDepositChanged(minDeposit);
    }

    /**
     * Change the maximum whitelist length. New value shall satisfy the #isAllowedWhitelist conditions.
     * @param maxWhitelistLength The maximum whitelist length
     */
    function setMaxWhitelistLength(uint256 maxWhitelistLength) external onlyOwner beforeEnd {
        setMaxWhitelistLengthInternal(maxWhitelistLength);
    }

    /**
     * Change the whitelist threshold balance. New value shall satisfy the #isAllowedWhitelist conditions.
     * @param whitelistThreshold The threshold balance (in wei) above which whitelisting is required to invest
     */
    function setWhitelistThresholdBalance(uint256 whitelistThreshold) external onlyOwner beforeEnd {
        setWhitelistThresholdBalanceInternal(whitelistThreshold);
    }

    /**
     * Add the subscriber to the whitelist.
     * @param subscriber The subscriber to add to the whitelist.
     */
    function addToWhitelist(address subscriber) external onlyOwner beforeEnd {
        addToWhitelistInternal(subscriber);
    }

    /**
     * Removed the subscriber from the whitelist.
     * @param subscriber The subscriber to remove from the whitelist.
     */
    function removeFromWhitelist(address subscriber) external onlyOwner beforeEnd {
        removeFromWhitelistInternal(subscriber, balanceOf[subscriber]);
    }

    // // fallback function can be used to buy tokens
    // function () external payable whenNotPaused {
    //     buyTokens(msg.sender);
    // }

    // No payable fallback function, the tokens must be buyed using the functions buyTokens and buyTokensFor
    function () external {
        revert("No payable fallback function");
    }

    function uint2str(uint i) internal pure returns (string memory){
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0){
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint k = length - 1;
        while (i != 0){
            bstr[k--] = byte(uint8(48 + i % 10));
            i /= 10;
        }
        return string(bstr);
    }

    // low level token purchase function
    // function buyTokens(address beneficiary) public payable whenNotPaused {
    function releaseTokensTo(address beneficiary) internal whenNotPaused returns(bool) {
        require(beneficiary != address(0), "beneficiary is zero");
        require(isValidPurchase(beneficiary), "invalid purchase by beneficiary");

        balanceOf[beneficiary] = balanceOf[beneficiary].add(msg.value);

        raisedFunds = raisedFunds.add(msg.value);

        uint256 tokenAmount = calculateTokens(msg.value);

        soldTokens = soldTokens.add(tokenAmount);

        // revert(appendStr("releaseTokensTo", toAsciiString(beneficiary), uint2str(tokenAmount)));

        distributeTokens(beneficiary, tokenAmount);

        //distributeTokens(address(0), 1);

        emit LogTokenPurchase(msg.sender, beneficiary, msg.value, tokenAmount);

        forwardFunds(msg.value);

        return true;
    }

    /**
     * @dev Overrides Whitelistable#isAllowedBalance to add minimum deposit logic.
     */
    function isAllowedBalance(address beneficiary, uint256 balance) public view returns (bool isReallyAllowed) {
        bool hasMinimumBalance = balance >= minDeposit;
        return hasMinimumBalance && super.isAllowedBalance(beneficiary, balance);
    }

    /**
     * @dev Determine if the token purchase is valid or not.
     * @return true if the transaction can buy tokens
     */
    function isValidPurchase(address beneficiary) internal view returns (bool isValid) {
        bool withinPeriod = startBlock <= block.number && block.number <= endBlock;
        bool nonZeroPurchase = msg.value != 0;
        bool isValidBalance = isAllowedBalance(beneficiary, balanceOf[beneficiary].add(msg.value));

        return withinPeriod && nonZeroPurchase && isValidBalance;
    }

    // Calculate the token amount given the invested ether amount.
    // Override to create custom fund forwarding mechanisms
    function calculateTokens(uint256 amount) internal view returns (uint256 tokenAmount) {
        return amount.mul(rate);
    }

    /**
     * @dev Distribute the token amount to the beneficiary.
     * @notice Override to create custom distribution mechanisms
     */
    function distributeTokens(address beneficiary, uint256 tokenAmount) internal {
        token.mint(beneficiary, tokenAmount);
    }

    // Send ether amount to the fund collection wallet.
    // override to create custom fund forwarding mechanisms
    function forwardFunds(uint256 amount) internal;
}
