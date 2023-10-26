// SPDX-License-Identifier: MIT 
pragma solidity ^0.6.0;

import "../ERC1644.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";


contract ERC1644Token is ERC1644, ERC20Burnable {

    constructor(address _controller)
    public
    ERC1644(_controller,"Name","SYMBOL") {
        
    }
}