pragma solidity ^0.4.24;

import "./Library/SafeMath.sol";
import "./Library/AddressUtils.sol";
import "./ImplementContract/TokenCappedCrowdsaleKYC.sol";
import "./KTuneCustomERC20.sol";

/**
 * @title K-TuneCustomCrowdsaleKYC
 * @dev Extension of TokenCappedCrowdsaleKYC using values specific for K-Tune Custom ICO crowdsale
 */
contract KTuneCustomCrowdsaleKYC is TokenCappedCrowdsaleKYC {
    using AddressUtils for address;
    using SafeMath for uint256;

    event LogKTuneCustomCrowdsaleCreated(
        address sender,
        uint256 indexed startBlock,
        uint256 indexed endBlock,
        address indexed wallet
    );

    // The wallet address or not contract
    address public wallet;

    constructor(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rate,
        uint256 _minDeposit,
        address _token,
        uint256 _tokenMaximumSupply,
        address _wallet,
        address[] memory _kycSigner
    )
    CrowdsaleKYC(
        _startBlock,
        _endBlock,
        _rate,
        _minDeposit,
        1,
        1,
        _kycSigner
    )
    public {
        require(_token.isContract(), "_token is not contract");
        require(_tokenMaximumSupply > 0, "_tokenMaximumSupply is zero");

        token = KTuneCustomERC20(_token);
        wallet = _wallet;

        // Assume predefined token supply has been minted and calculate the maximum number of tokens that can be sold
        tokenCap = _tokenMaximumSupply.sub(token.totalSupply());

        emit LogKTuneCustomCrowdsaleCreated(msg.sender, startBlock, endBlock, _wallet);
    }

    function grantTokenOwnership(address _client) external onlyOwner returns(bool granted) {
        require(!_client.isContract(), "_client is contract");
        require(hasEnded(), "crowdsale not ended yet");

        // Transfer K-TuneCustomERC20 ownership back to the client
        token.transferOwnership(_client);

        return true;
    }

    /**
     * @dev Overriding Crowdsale#forwardFunds to split net/fee payment.
     */
    function forwardFunds(uint256 amount) internal {
        wallet.transfer(amount);
    }
}
