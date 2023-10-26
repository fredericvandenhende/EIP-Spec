// SPDX-License-Identifier: MIT 
pragma solidity ^0.6.0;

import "../ERC1594.sol";

contract ERC1594Token is ERC1594 {

    string private _name;
    string private _symbol;
    uint8 private  _decimals;
    constructor(string memory name, string memory symbol, uint8 decimals)  public   {
        _name=name;
        _symbol=symbol;
        _decimals=decimals;
    }

    event IssuanceFinalized();

    function finalizeIssuance() external onlyOwner {
        require(issuance, "Issuance already closed");
        issuance = false;
        emit IssuanceFinalized();
    }

}