// File: contracts\ERC20Frozenable.sol
    
pragma solidity ^0.5.2;
import "./ERC20Burnable.sol";
import "./ERC20Mintable.sol";
import "./Ownable.sol";
    //truffle-flattener Token.sol
    contract ERC20Frozenable is ERC20Burnable, ERC20Mintable, Ownable {
        mapping (address => bool) private _frozenAccount;
        event FrozenFunds(address target, bool frozen);
    
    
        function frozenAccount(address _address) public view returns(bool isFrozen) {
            return _frozenAccount[_address];
        }
    
        function freezeAccount(address target, bool freeze)  public onlyOwner {
            require(_frozenAccount[target] != freeze, "Same as current");
            _frozenAccount[target] = freeze;
            emit FrozenFunds(target, freeze);
        }
    
        function _transfer(address from, address to, uint256 value) internal {
            require(!_frozenAccount[from], "error - frozen");
            require(!_frozenAccount[to], "error - frozen");
            super._transfer(from, to, value);
        }
    
    }
