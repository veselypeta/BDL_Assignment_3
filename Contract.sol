// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "./customLibrary.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract Contract {

    uint256 public tokenPrice; // public price of tokens


    uint256 contractBalance; // balance of the contract in wei
    uint256 contractTokens; // how many tokens are currently in circulation
    address owner; // the owner of the contract
    mapping(address => uint256) tokenBalance; // balance of each customer in tokens
    bool firstToken;
    
    // Events
    event Purchase(address buyer, uint256 amount);
    event Transfer(address sender, address receiver, uint amount);
    event Sell(address seller, uint256 amount);
    event Price(uint256 amount);

    constructor(uint256 _price) payable {
        // contract owner covers the cost of first 'cheap' token
        require(msg.value >= _price, "not enough value in constructor");
        tokenPrice = _price;
        owner = msg.sender;
        contractBalance = msg.value;
        contractTokens = 0;
        firstToken = true;
    }


    // function via which a user purchases amount number of
    // tokens by paying the equivalent price in wei; if the purchase is successful, the function
    // returns a boolean value (true) and emits an event Purchase with the buyer’s address and
    // the purchased amount
    function buyToken(uint256 amount) public payable returns (bool) {
        require(amount > 0, "must be positive amount");
        // purchasing zero tokens always succeeds
        if(amount == 0){
            return true;
        }

        // first token must be bought by contracts creator
        uint256 cost;
        if(firstToken){
            // We sell the first token at tokenPrice, then we double the cost of subsequent tokens
            // tokenPrice + ((amount - 1) * 2 * tokenPrice);
            cost = SafeMath.add(tokenPrice, SafeMath.mul(SafeMath.mul(SafeMath.sub(amount, 1), 2), tokenPrice));
            Contract.changePrice(SafeMath.mul(tokenPrice, 2));
            firstToken = false; 
        } else {
            cost = SafeMath.mul(amount, tokenPrice);
        }

        require(msg.value >= cost, "must supply enough value");
            
        // how much wei was oversent?
        uint256 remainder = SafeMath.sub(msg.value, cost);
        // update the tokens
        tokenBalance[msg.sender] = SafeMath.add(tokenBalance[msg.sender], amount);

        // update the contract's balance & tokens to reflect the purchase
        contractBalance = SafeMath.add(contractBalance, cost);
        contractTokens = SafeMath.add(contractTokens, amount);

        // emit purchase
        emit Purchase(msg.sender, amount);
        // refund any remaining funds
        if(remainder > 1){
            return customLib.customSend(remainder, msg.sender);
        }

        return true;
    }

    /*
    a function that transfers amount number of
    tokens from the account of the transaction’s sender to the recipient; if the transfer is
    successful, the function returns a boolean value (true) and emits an event Transfer, with the
    sender’s and receiver’s addresses and the transferred amount
    */
    function transfer(address recipient, uint amount) public returns (bool){
        // must have enough tokens to be able to send them
        require(tokenBalance[msg.sender] >= amount, "not enough tokens");
        // can transfer to themselves
        require(msg.sender != recipient, "cant transfer to yourslef");

        // update the balance to reflect the transfer
        tokenBalance[msg.sender] = SafeMath.sub(tokenBalance[msg.sender], amount);
        tokenBalance[recipient] = SafeMath.add(tokenBalance[recipient], amount);

        // balance and total tokens in circulation is unnaffected

        // emit the event
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    // a function via which a user sells amount number of tokens
    // and receives from the contract tokenPrice wei for each sold token; if the sell is successful,
    // the sold tokens are destroyed, the function returns a boolean value (true) and emits an
    // event Sell with the seller’s address and the sold amount of tokens
    function sellToken(uint256 amount) public returns (bool){
        // must have enough tokens to sell
        require(tokenBalance[msg.sender] >= amount && contractTokens >= amount, "not enough tokens");

        uint256 sell_cost = SafeMath.mul(amount, tokenPrice);
        require(sell_cost <= contractBalance, "note enough balance"); // contract must be able to afford the sale

        // update state to reflect sale
        tokenBalance[msg.sender] = SafeMath.sub(tokenBalance[msg.sender], amount);
        contractTokens = SafeMath.sub(contractTokens, amount);
        contractBalance = SafeMath.sub(contractBalance, sell_cost);

        emit Sell(msg.sender, amount);

        // send the wei to requestor
        return customLib.customSend(sell_cost, msg.sender);
    }

    // a function via which the contract’s creator can change the
    // tokenPrice; if the action is successful, the function returns a boolean value (true) and emits
    // an event Price with the new price (Note: make sure that, whenever the price changes, the
    // contract’s funds suffice so that all tokens can be sold for the updated price)    
    function changePrice(uint256 price) public returns (bool){
        // only the owner can change the price of coins
        require(msg.sender == owner);
        uint256 tknWorth = SafeMath.mul(price, contractTokens);
        require(tknWorth <= contractBalance); // the contract can sell all tokens at the new price
        tokenPrice = price;
        emit Price(price);
        return true;
    }

    // a view that returns the amount of tokens that the user owns
    function getBalance() public view returns (uint){
        return tokenBalance[msg.sender];
    }

}