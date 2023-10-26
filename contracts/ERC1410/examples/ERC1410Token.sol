// SPDX-License-Identifier: MIT 
pragma solidity ^0.6.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../ERC1410Standard.sol";

/**
 * @title Standard ERC1644 token
 */
contract ERC1410Token is ERC1410Standard, ERC20 {
    
    constructor(string memory _name, string memory _symbol)
    public 
    ERC20(_name,_symbol)    {
    }
/**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override(ERC20, ERC1410Standard) returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override(ERC20, ERC1410Standard) returns (uint256) {
        return balances[account];
    }
}