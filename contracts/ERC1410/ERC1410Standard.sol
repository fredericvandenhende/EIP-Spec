// SPDX-License-Identifier: MIT 
pragma solidity ^0.6.0;

import "./IERC1410Partitioned.sol";
import "./IERC1410Aggregated.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../math/KindMath.sol";

contract ERC1410Standard is IERC1410Partitioned, IERC1410Aggregated, Ownable {

    // Partitions
    bytes32 public constant HELD_FREE_PARTITION = 0x7465737400000000000000000000000000000000000000000000000000000000;
    bytes32 public constant TRANSIT_PARTITION = 0x7465737600000000000000000000000000000000000000000000000000000000;
    bytes32 public constant UNCONFIRMED_PARTITION = 0x7465737800000000000000000000000000000000000000000000000000000000;

    
    using SafeMath for uint256;

    // Represents a fungible set of tokens.
    struct Partition {
        uint256 amount;
        bytes32 partition;
    }

    uint256 _totalSupply;

    // Mapping from investor to aggregated balance across all investor token sets
    mapping (address => uint256) balances;

    // Mapping from investor to their partitions
    mapping (address => Partition[]) partitions;

    // Mapping from (investor, partition) to index of corresponding partition in partitions
    // @dev Stored value is always greater by 1 to avoid the 0 value of every index
    mapping (address => mapping (bytes32 => uint256)) partitionToIndex;

    event TransferByPartition(
        bytes32 indexed _fromPartition,
        address _operator,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );

  /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return balances[account];
    }


    /// @notice Counts the balance associated with a specific partition assigned to an tokenHolder
    /// @param _partition The partition for which to query the balance
    /// @param _tokenHolder An address for whom to query the balance
    /// @return The number of tokens owned by `_tokenHolder` with the metadata associated with `_partition`, possibly zero
    function balanceOfByPartition(bytes32 _partition, address _tokenHolder) external override view returns (uint256) {
        if (_validPartition(_partition, _tokenHolder))
            return partitions[_tokenHolder][partitionToIndex[_tokenHolder][_partition] - 1].amount;
        else
            return 0;
    }

    /// @notice Use to get the list of partitions `_tokenHolder` is associated with
    /// @param _tokenHolder An address corresponds whom partition list is queried
    /// @return List of partitions
    function partitionsOf(address _tokenHolder) external override view returns (bytes32[] memory) {
        bytes32[] memory partitionsList = new bytes32[](partitions[_tokenHolder].length);
        for (uint256 i = 0; i < partitions[_tokenHolder].length; i++) {
            partitionsList[i] = partitions[_tokenHolder][i].partition;
        } 
        return partitionsList;
    }

    /// @notice Transfers the ownership of tokens from a specified partition from one address to another address
    /// @param _partition The partition from which to transfer tokens
    /// @param _to The address to which to transfer tokens to
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    /// @return The partition to which the transferred tokens were allocated for the _to address
    function transferByPartition(bytes32 _partition, address _to, uint256 _value, bytes calldata _data) external override returns (bytes32) {
        // Add a function to verify the `_data` parameter
        // TODO: Need to create the bytes division of the `_partition` so it can be easily findout in which receiver's partition
        // token will transfered. For current implementation we are assuming that the receiver's partition will be same as sender's
        // as well as it also pass the `_validPartition()` check. In this particular case we are also assuming that reciever has the
        // some tokens of the same partition as well (To avoid the array index out of bound error).
        // Note- There is no operator used for the execution of this call so `_operator` value in
        // in event is address(0) same for the `_operatorData`
        _transferByPartition(msg.sender, _to, _value, _partition, _data, address(0), "");
    }

    /// @notice Transfers the ownership of tokens from a specified partition from one address to another address
    /// @param _to The address to which to transfer tokens to
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    /// @return The partition to which the transferred tokens were allocated for the _to address
    function transfer(address _to, uint256 _value, bytes calldata _data) external override returns (bytes32) {
        // Add a function to verify the `_data` parameter
        // TODO: Need to create the bytes division of the `_partition` so it can be easily findout in which receiver's partition
        // token will transfered. For current implementation we are assuming that the receiver's partition will be same as sender's
        // as well as it also pass the `_validPartition()` check. In this particular case we are also assuming that reciever has the
        // some tokens of the same partition as well (To avoid the array index out of bound error).
        // Note- There is no operator used for the execution of this call so `_operator` value in
        // in event is address(0) same for the `_operatorData`
        bytes32 _partition=HELD_FREE_PARTITION;
        _transferByPartition(msg.sender, _to, _value, _partition, _data, address(0), "");
    }
    /// @notice The standard provides an on-chain function to determine whether a transfer will succeed,
    /// and return details indicating the reason if the transfer is not valid.
    /// @param _from The address from whom the tokens get transferred.
    /// @param _to The address to which to transfer tokens to.
    /// @param _partition The partition from which to transfer tokens
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    /// @return ESC (Ethereum Status Code) following the EIP-1066 standard
    /// @return Application specific reason codes with additional details
    /// @return The partition to which the transferred tokens were allocated for the _to address
    function canTransferByPartition(address _from, address _to, bytes32 _partition, uint256 _value, bytes calldata _data) external override view returns (bytes1, bytes32, bytes32) {
        // TODO: Applied the check over the `_data` parameter
        if (!_validPartition(_partition, _from))
            return (0x50, "Partition not exists", bytes32(""));
        else if (partitions[_from][partitionToIndex[_from][_partition]].amount < _value)
            return (0x52, "Insufficent balance", bytes32(""));
        else if (_to == address(0))
            return (0x57, "Invalid receiver", bytes32(""));
        else if (!KindMath.checkSub(balances[_from], _value) || !KindMath.checkAdd(balances[_to], _value))
            return (0x50, "Overflow", bytes32(""));
        
        // Call function to get the receiver's partition. For current implementation returning the same as sender's
        return (0x51, "Success", _partition);
    }

    /// @notice The standard provides an on-chain function to determine whether a transfer will succeed,
    /// and return details indicating the reason if the transfer is not valid.
    /// @param _from The address from whom the tokens get transferred.
    /// @param _to The address to which to transfer tokens to.
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    /// @return ESC (Ethereum Status Code) following the EIP-1066 standard
    /// @return Application specific reason codes with additional details
    /// @return The partition to which the transferred tokens were allocated for the _to address
    function canTransfer(address _from, address _to,  uint256 _value, bytes calldata _data) external override view returns (bytes1, bytes32, bytes32) {
        bytes32 _partition=HELD_FREE_PARTITION;
        // TODO: Applied the check over the `_data` parameter
        if (!_validPartition(_partition, _from))
            return (0x50, "Partition not exists", bytes32(""));
        else if (partitions[_from][partitionToIndex[_from][_partition]].amount < _value)
            return (0x52, "Insufficent balance", bytes32(""));
        else if (_to == address(0))
            return (0x57, "Invalid receiver", bytes32(""));
        else if (!KindMath.checkSub(balances[_from], _value) || !KindMath.checkAdd(balances[_to], _value))
            return (0x50, "Overflow", bytes32(""));
        
        // Call function to get the receiver's partition. For current implementation returning the same as sender's
        return (0x51, "Success", _partition);
    }
    function _transferByPartition(address _from, address _to, uint256 _value, bytes32 _partition, bytes memory _data, address _operator, bytes memory _operatorData) internal {
        require(_validPartition(_partition, _from), "Invalid partition"); 
        require(partitions[_from][partitionToIndex[_from][_partition] - 1].amount >= _value, "Insufficient balance");
        require(_to != address(0), "0x address not allowed");
        uint256 _fromIndex = partitionToIndex[_from][_partition] - 1;
        
        if (! _validPartitionForReceiver(_partition, _to)) {
            partitions[_to].push(Partition(0, _partition));
            partitionToIndex[_to][_partition] = partitions[_to].length;
        }
        uint256 _toIndex = partitionToIndex[_to][_partition] - 1;
        
        // Changing the state values
        partitions[_from][_fromIndex].amount = partitions[_from][_fromIndex].amount.sub(_value);
        balances[_from] = balances[_from].sub(_value);
        partitions[_to][_toIndex].amount = partitions[_to][_toIndex].amount.add(_value);
        balances[_to] = balances[_to].add(_value);
        // Emit transfer event.
        emit TransferByPartition(_partition, _operator, _from, _to, _value, _data, _operatorData);
    }

    function _validPartition(bytes32 _partition, address _holder) internal view returns(bool) {
        if (partitions[_holder].length < partitionToIndex[_holder][_partition] || partitionToIndex[_holder][_partition] == 0)
            return false;
        else
            return true;
    }
    
    function _validPartitionForReceiver(bytes32 _partition, address _to) public view returns(bool) {
        for (uint256 i = 0; i < partitions[_to].length; i++) {
            if (partitions[_to][i].partition == _partition) {
                return true;
            }
        }
        
        return false;
    }
    
    // Mapping from (investor, partition, operator) to approved status
    mapping (address => mapping (bytes32 => mapping (address => bool))) partitionApprovals;

    // Mapping from (investor, operator) to approved status (can be used against any partition)
    mapping (address => mapping (address => bool)) approvals;

    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);

    event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

    /// @notice Determines whether `_operator` is an operator for all partitions of `_tokenHolder`
    /// @param _operator The operator to check
    /// @param _tokenHolder The token holder to check
    /// @return Whether the `_operator` is an operator for all partitions of `_tokenHolder`
    function isOperator(address _operator, address _tokenHolder) public override view returns (bool) {
        return approvals[_tokenHolder][_operator];
    }

    /// @notice Determines whether `_operator` is an operator for a specified partition of `_tokenHolder`
    /// @param _partition The partition to check
    /// @param _operator The operator to check
    /// @param _tokenHolder The token holder to check
    /// @return Whether the `_operator` is an operator for a specified partition of `_tokenHolder`
    function isOperatorForPartition(bytes32 _partition, address _operator, address _tokenHolder) public override view returns (bool) {
        return partitionApprovals[_tokenHolder][_partition][_operator];
    }

    ///////////////////////
    /// Operator Management
    ///////////////////////

    /// @notice Authorises an operator for all partitions of `msg.sender`
    /// @param _operator An address which is being authorised
    function authorizeOperator(address _operator) external override {
        approvals[msg.sender][_operator] = true;
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /// @notice Revokes authorisation of an operator previously given for all partitions of `msg.sender`
    /// @param _operator An address which is being de-authorised
    function revokeOperator(address _operator) external override {
        approvals[msg.sender][_operator] = false;
        emit RevokedOperator(_operator, msg.sender);
    }

    /// @notice Authorises an operator for a given partition of `msg.sender`
    /// @param _partition The partition to which the operator is authorised
    /// @param _operator An address which is being authorised
    function authorizeOperatorByPartition(bytes32 _partition, address _operator) external override {
        partitionApprovals[msg.sender][_partition][_operator] = true;
        emit AuthorizedOperatorByPartition(_partition, _operator, msg.sender);
    }

    /// @notice Revokes authorisation of an operator previously given for a specified partition of `msg.sender`
    /// @param _partition The partition to which the operator is de-authorised
    /// @param _operator An address which is being de-authorised
    function revokeOperatorByPartition(bytes32 _partition, address _operator) external override {
        partitionApprovals[msg.sender][_partition][_operator] = false;
        emit RevokedOperatorByPartition(_partition, _operator, msg.sender);
    }

    /// @notice Transfers the ownership of tokens from a specified partition from one address to another address
    /// @param _partition The partition from which to transfer tokens
    /// @param _from The address from which to transfer tokens from
    /// @param _to The address to which to transfer tokens to
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    /// @param _operatorData Additional data attached to the transfer of tokens by the operator
    /// @return The partition to which the transferred tokens were allocated for the _to address
    function operatorTransferByPartition(bytes32 _partition, address _from, address _to, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external override returns (bytes32) {
        // TODO: Add a functionality of verifying the `_operatorData`
        // TODO: Add a functionality of verifying the `_data`
        require(
            isOperator(msg.sender, _from) || isOperatorForPartition(_partition, msg.sender, _from),
            "Not authorised"
        );
        _transferByPartition(_from, _to, _value, _partition, _data, msg.sender, _operatorData);
    }
    /// @notice Transfers the ownership of tokens from a specified partition from one address to another address
    /// @param _from The address from which to transfer tokens from
    /// @param _to The address to which to transfer tokens to
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    /// @param _operatorData Additional data attached to the transfer of tokens by the operator
    /// @return The partition to which the transferred tokens were allocated for the _to address
    function operatorTransfer( address _from, address _to, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external override returns (bytes32) {
        bytes32 _partition=HELD_FREE_PARTITION;
        // TODO: Add a functionality of verifying the `_operatorData`
        // TODO: Add a functionality of verifying the `_data`
        require(
            isOperator(msg.sender, _from) || isOperatorForPartition(_partition, msg.sender, _from),
            "Not authorised"
        );
        _transferByPartition(_from, _to, _value, _partition, _data, msg.sender, _operatorData);
    }
    /// @notice Increases totalSupply and the corresponding amount of the specified owners partition
    /// @param _partition The partition to allocate the increase in balance
    /// @param _tokenHolder The token holder whose balance should be increased
    /// @param _value The amount by which to increase the balance
    /// @param _data Additional data attached to the minting of tokens
    function issueByPartition(bytes32 _partition, address _tokenHolder, uint256 _value, bytes calldata _data) external override onlyOwner {
        // Add the function to validate the `_data` parameter
        _issueByPartition(_partition, _tokenHolder, _value, _data, "");
    }

    /// @notice Increases totalSupply and the corresponding amount of the specified owners partition
    /// @param _tokenHolder The token holder whose balance should be increased
    /// @param _value The amount by which to increase the balance
    /// @param _data Additional data attached to the minting of tokens
    function issue( address _tokenHolder, uint256 _value, bytes calldata _data) external override onlyOwner {
        // Add the function to validate the `_data` parameter
        bytes32 _partition=HELD_FREE_PARTITION;
        _issueByPartition(_partition, _tokenHolder, _value, _data, "");
    }

    function operatorIssue( address _tokenHolder, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external override  {
        bytes32 _partition=HELD_FREE_PARTITION;
        require(
            isOperator(msg.sender, _tokenHolder) || isOperatorForPartition(_partition, msg.sender, _tokenHolder),
            "Not authorised"
        );
        _issueByPartition(_partition, _tokenHolder, _value, _data, _operatorData);
    }
    function operatorIssueByPartition(bytes32 _partition, address _tokenHolder, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external override  {
        require(
            isOperator(msg.sender, _tokenHolder) || isOperatorForPartition(_partition, msg.sender, _tokenHolder),
            "Not authorised"
        );
        // Add the function to validate the `_data` parameter
        _issueByPartition(_partition, _tokenHolder, _value, _data, _operatorData);
    }
    function _issueByPartition(bytes32 _partition, address _tokenHolder, uint256 _value, bytes memory _data, bytes memory _operatorData) internal {
    // Add the function to validate the `_data` parameter
        _validateParams(_partition, _value);
        require(_tokenHolder != address(0), "Invalid token receiver");
        uint256 index = partitionToIndex[_tokenHolder][_partition];
        if (index == 0) {
            partitions[_tokenHolder].push(Partition(_value, _partition));
            partitionToIndex[_tokenHolder][_partition] = partitions[_tokenHolder].length;
        } else {
            partitions[_tokenHolder][index - 1].amount = partitions[_tokenHolder][index - 1].amount.add(_value);
        }
        _totalSupply = _totalSupply.add(_value);
        balances[_tokenHolder] = balances[_tokenHolder].add(_value);
        emit IssuedByPartition(_partition, _tokenHolder, _value, _data);
    }

    /// @notice Decreases totalSupply and the corresponding amount of the specified partition of msg.sender
    /// @param _value The amount by which to decrease the balance
    /// @param _data Additional data attached to the burning of tokens
    function redeem( uint256 _value, bytes calldata _data) external override {
        // Add the function to validate the `_data` parameter
        _redeemByPartition(HELD_FREE_PARTITION, msg.sender, address(0), _value, _data, "");
    }

    /// @notice Decreases totalSupply and the corresponding amount of the specified partition of msg.sender
    /// @param _partition The partition to allocate the decrease in balance
    /// @param _value The amount by which to decrease the balance
    /// @param _data Additional data attached to the burning of tokens
    function redeemByPartition(bytes32 _partition, uint256 _value, bytes calldata _data) external override {
        // Add the function to validate the `_data` parameter
        _redeemByPartition(_partition, msg.sender, address(0), _value, _data, "");
    }

    /// @notice Decreases totalSupply and the corresponding amount of the specified partition of tokenHolder
    /// @dev This function can only be called by the authorised operator.
    /// @param _tokenHolder The token holder whose balance should be decreased
    /// @param _value The amount by which to decrease the balance
    /// @param _data Additional data attached to the burning of tokens
    /// @param _operatorData Additional data attached to the transfer of tokens by the operator
    function operatorRedeem( address _tokenHolder, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external override {
        bytes32 _partition=HELD_FREE_PARTITION;
        require(_tokenHolder != address(0), "Invalid from address");
        require(
            isOperator(msg.sender, _tokenHolder) || isOperatorForPartition(_partition, msg.sender, _tokenHolder),
            "Not authorised"
        );
        _redeemByPartition(_partition, _tokenHolder, msg.sender, _value, _data, _operatorData);
    }
    /// @notice Decreases totalSupply and the corresponding amount of the specified partition of tokenHolder
    /// @dev This function can only be called by the authorised operator.
    /// @param _partition The partition to allocate the decrease in balance.
    /// @param _tokenHolder The token holder whose balance should be decreased
    /// @param _value The amount by which to decrease the balance
    /// @param _data Additional data attached to the burning of tokens
    /// @param _operatorData Additional data attached to the transfer of tokens by the operator
    function operatorRedeemByPartition(bytes32 _partition, address _tokenHolder, uint256 _value, bytes calldata _data, bytes calldata _operatorData) external override {
        // Add the function to validate the `_data` parameter
        // TODO: Add a functionality of verifying the `_operatorData`
        require(_tokenHolder != address(0), "Invalid from address");
        require(
            isOperator(msg.sender, _tokenHolder) || isOperatorForPartition(_partition, msg.sender, _tokenHolder),
            "Not authorised"
        );
        _redeemByPartition(_partition, _tokenHolder, msg.sender, _value, _data, _operatorData);
    }

    function _redeemByPartition(bytes32 _partition, address _from, address _operator, uint256 _value, bytes memory _data, bytes memory _operatorData) internal {
        // Add the function to validate the `_data` parameter
        _validateParams(_partition, _value);
        require(_validPartition(_partition, _from), "Invalid partition");
        uint256 index = partitionToIndex[_from][_partition] - 1;
        require(partitions[_from][index].amount >= _value, "Insufficient value");
        if (partitions[_from][index].amount == _value) {
            _deletePartitionForHolder(_from, _partition, index);
        } else {
            partitions[_from][index].amount = partitions[_from][index].amount.sub(_value);
        }
        balances[_from] = balances[_from].sub(_value);
        _totalSupply = _totalSupply.sub(_value);
        emit RedeemedByPartition(_partition, _operator, _from, _value, _data, _operatorData);
    }

    function _deletePartitionForHolder(address _holder, bytes32 _partition, uint256 index) internal {
        if (index != partitions[_holder].length -1) {
            partitions[_holder][index] = partitions[_holder][partitions[_holder].length -1];
            partitionToIndex[_holder][partitions[_holder][index].partition] = index + 1;
        }
        delete partitionToIndex[_holder][_partition];
        //FIXME partitions[_holder].length--;
    }

    function _validateParams(bytes32 _partition, uint256 _value) internal pure {
        require(_value != uint256(0), "Zero value not allowed");
        require(_partition != bytes32(0), "Invalid partition");
        require(_partition == HELD_FREE_PARTITION || _partition == TRANSIT_PARTITION || _partition == UNCONFIRMED_PARTITION, "Partition should be HELD_FREE_PARTITION or TRANSIT_PARTITION or UNCONFIRMED_PARTITION ");
    }

}