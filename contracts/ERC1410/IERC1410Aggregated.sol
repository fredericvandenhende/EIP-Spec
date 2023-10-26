
pragma solidity ^0.6.0; 

interface IERC1410Aggregated {

    // Token Information
    function balanceOf(address _tokenHolder) external view returns (uint256);
    function totalSupply() external view returns (uint256);

    // Token Transfers
    function transfer(address _to, uint256 _value, bytes calldata _data) external returns (bytes32);
    function operatorTransfer(address _from, address _to, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external returns (bytes32);
    function canTransfer(address _from, address _to, uint256 _value, bytes calldata _data) external view returns (byte, bytes32, bytes32);    

    // Operator Information
    function isOperator(address _operator, address _tokenHolder) external view returns (bool);

    // Operator Management
    function authorizeOperator(address _operator) external;
    function revokeOperator(address _operator) external;

    // Issuance / Redemption
    function issue( address _tokenHolder, uint256 _value, bytes calldata _data) external;
    function redeem(uint256 _value, bytes calldata _data) external;
    function operatorRedeem(address _tokenHolder, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external;
    function operatorIssue(address _tokenHolder, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external;

    // Transfer Events
    event Transfer(
        address _operator,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );

    // Operator Events
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);

    // Issuance / Redemption Events
    event Issued(address indexed to, uint256 value, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data, bytes operatorData);

}
