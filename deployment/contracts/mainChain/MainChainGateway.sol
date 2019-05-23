pragma solidity ^0.4.24;

import "../common/token/TRC721/TRC721.sol";
import "../common/token/TRC20/TRC20.sol";
import "../common/math/SafeMath.sol";
import "../common/token/TRC721/ITRC721Receiver.sol";
import "../common/token/TRC20/ITRC20Receiver.sol";
import "./OracleManagerContract.sol";


contract MainChainGateway is  ITRC20Receiver, ITRC721Receiver, OracleManagerContract {

    using SafeMath for uint256;

    struct Balance {
        uint256 tron;
        mapping(uint256 => uint256) trc10;
        mapping(address => uint256) trc20;
        mapping(address => mapping(uint256 => bool)) trc721;
    }

    Balance balances;

    event TRXReceived(address from, uint256 amount);
    event TRC10Received(address from, uint256 amount, uint256 tokenId);
    event TRC20Received(address from, uint256 amount, address contractAddress);
    event TRC721Received(address from, uint256 uid, address contractAddress);

    enum TokenKind {
        TRX,
        TRC10,
        TRC20,
        TRC721
    }
    
    /**
     * Event to log the withdrawal of a token from the Gateway.
     * @param owner Address of the entity that made the withdrawal.
     * @param kind The type of token withdrawn (TRC20/TRC721/TRX/TRC10).
     * @param contractAddress Address of token contract the token belong to.
     * @param value For TRC721 this is the uid of the token, for TRX/TRC20/TRC10 this is the amount.
     */
    event TokenWithdrawn(address indexed owner, TokenKind kind, address contractAddress, uint256 value);
    event Token10Withdrawn(address indexed owner, TokenKind kind, trcToken tokenId, uint256 value);

    constructor (address _oracle)
    public OracleManagerContract(_oracle) {
    }

    // Deposit functions

    function _depositTRC721(uint256 uid) private {
        balances.trc721[msg.sender][uid] = true;
    }

    function _depositTRC20(uint256 amount) private {
        balances.trc20[msg.sender] = balances.trc20[msg.sender].add(amount);
    }

    // Withdrawal functions
    function withdrawTRC20(address _to, address contractAddress, uint256 amount, bytes sig)
    public
    checkGainer(_to, amount, contractAddress, sig)
    {
        balances.trc20[contractAddress] = balances.trc20[contractAddress].sub(amount);
        TRC20(contractAddress).transfer(_to, amount);
        emit TokenWithdrawn(_to, TokenKind.TRC20, contractAddress, amount);
    }

    function withdrawTRC721(address _to, address contractAddress,uint256 uid, bytes sig)
    public
    checkGainer(_to,uid, contractAddress, sig)
    {
        require(balances.trc721[contractAddress][uid], "Does not own token");
        TRC721(contractAddress).transfer(_to, uid);
        delete balances.trc721[contractAddress][uid];
        emit TokenWithdrawn(_to, TokenKind.TRC721, contractAddress, uid);
    }

    function withdrawTRX(address _to, uint256 amount, bytes sig)
    public
    checkGainer(_to,amount, address(this), sig)
    {
        balances.tron = balances.tron.sub(amount);
        _to.transfer(amount);
        // ensure it's not reentrant
        emit TokenWithdrawn(_to, TokenKind.TRX, address(0), amount);
    }

    function withdrawTRC10(address _to, trcToken tokenId, uint256 amount, bytes sig)
    public
    checkTrc10Gainer(_to,amount, tokenId, sig)
    {
        balances.trc10[tokenId] = balances.trc10[tokenId].sub(amount);
        _to.transferToken(amount, tokenId);
        emit Token10Withdrawn(msg.sender, TokenKind.TRC10, tokenId, amount);
    }

    // Approve and Deposit function for 2-step deposits
    // Requires first to have called `approve` on the specified TRC20 contract
    function depositTRC20(uint256 amount, address contractAddress) public {
        require(allowes[contractAddress]!=address(0), "Not an allowe token");
        TRC20(contractAddress).transferFrom(msg.sender, address(this), amount);
        balances.trc20[contractAddress] = balances.trc20[contractAddress].add(amount);
        emit TRC20Received(msg.sender, amount, contractAddress);
    }
    function depositTRC721(uint256 uid, address contractAddress) public {
        require(allowes[contractAddress]!=address(0), "Not an allowe token");
        TRC721(contractAddress).transferFrom(msg.sender, address(this), uid);
        balances.trc721[contractAddress][uid] = true;
        emit TRC721Received(msg.sender, uid, contractAddress);
    }

    function depositTRX() payable public {
        balances.tron = balances.tron.add(msg.value);
        emit TRXReceived(msg.sender, msg.value);
    }

    function depositTRC10() payable public {
        balances.trc10[msg.tokenid] = balances.trc10[msg.tokenid].add(msg.tokenvalue);
        emit TRC10Received(msg.sender, msg.tokenvalue, msg.tokenid);
    }

    // Receiver functions for 1-step deposits to the gateway


    function onTRC20Received(address _from, uint256 amount,bytes)
    public
    returns (bytes4)
    {
        require(allowes[msg.sender]!=address(0), "Not an allowe token");
        _depositTRC20(amount);
        emit TRC20Received(_from, amount, msg.sender);
        return _TRC20_RECEIVED;
    }

    function onTRC721Received(address _from, uint256 _uid, bytes)
    public
    returns (bytes4)
    {
        require(allowes[msg.sender]!=address(0), "Not an allowe token");
        _depositTRC721(_uid);
        emit TRC721Received(_from, _uid, msg.sender);
        return _TRC721_RECEIVED;
    }

    function() external payable {
        if (msg.tokenid > 1000000) {
            depositTRC10();
        }else if(msg.value > 0){
            depositTRX();
        }
    }

    // Returns all the TRX
    function getTRX() external view returns (uint256) {
        return balances.tron;
    }

    // Returns all the TRC10
    function getTRC10(uint256 tokenId) external view returns (uint256) {
        return balances.trc10[tokenId];
    }

    // Returns all the TRC20
    function getTRC20(address contractAddress) external view returns (uint256) {
        return balances.trc20[contractAddress];
    }

    // Returns TRC721 token by uid
    function getNFT(uint256 uid, address contractAddress) external view returns (bool) {
        return balances.trc721[contractAddress][uid];
    }
}
