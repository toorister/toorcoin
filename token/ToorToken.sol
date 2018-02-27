pragma solidity ^0.4.18;


import "./ERC20Basic.sol";
//import "../../math/SafeMath.sol";


/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract ToorToken is ERC20Basic {
    //using SafeMath for uint256;

    struct Account {
        uint balance;
        uint lastTime;
    }

    mapping(address => Account) accounts;

    uint256 totalSupply_;
    uint256 maxSupply_;
    uint256 startTime;
    uint256 pendingDividendsToGenerate;

    string public name;
    uint public decimals;
    string public symbol;

    uint256 private dividendInterval;
    uint256 private maxNoOfDividendPayouts;
    uint256 private vestingPeriod;
    uint256 private cliff;
    uint256 private pendingInstallments;
    uint256 private totalVestingPool;
    uint256 private pendingVestingPool;
    uint256 private dividendRate;
    address private founder1 = 0xeD20cae0BF1FF4054E1a12bb071d41c95B5C94b5;
    address private founder2 = 0x220Aad0b0bf12fF7245A29cbBA8fcfe72D0dE5d9;
    address private founder3 = 0xc97dfb488407189C5b6d784678b6Dc8516Be88ca;
    address private founder4 = 0x9fD5979af1B5048B05A0e5d8bf2362938C66c1c8;
    address private founder5 = 0x91C3f66A7Bd302DEb55C2ffd0421D48F63DBE011;
    address private company = 0x14278b24e40138822aD75EC740c23e3a99300DBf;
    address private bounty = 0x21445651dD395761544eF1658C5fFd2de7Ca45aC;

    function ToorToken() {
        maxSupply_ = 100000000 * 10**18;
        totalSupply_ = 13000000 * 10**18;
        accounts[company].balance = 9750000 * 10**18;
        accounts[bounty].balance = 3250000 * 10**18;
        name = "ToorCoin";
        decimals = 18;
        symbol = "TOOR";
        startTime = now;
        pendingInstallments = 4;
        totalVestingPool = 5000000 * 10**18;
        pendingVestingPool = 5000000 * 10**18;
        pendingDividendsToGenerate = maxSupply_ - totalSupply_ - totalVestingPool;
        dividendInterval = 86400;  // This is 1 day in seconds
        vestingPeriod = 7776000; // This equals 3 months
        cliff = vestingPeriod * 2; // This equals 6 months
        dividendRate = 1.000213 * 10**6; // Think about decimal places
    }

    /**
    * @dev total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function maxSupply() public view returns (uint256) {
        return maxSupply_;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balanceOf(msg.sender));

        addDividends(_to);
        addDividends(msg.sender);

        accounts[msg.sender].balance -= _value;
        accounts[_to].balance += _value;

        accounts[msg.sender].lastTime = now;
        accounts[_to].lastTime = now;

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function addDividends(address owner) private returns (bool) {
        if (dividendsOwed(owner) > 0) {
            accounts[owner].balance += dividendsOwed(owner);
        }

        return;
    }

    function vestTokens() public returns (bool) {
        require(pendingInstallments > 0);
        require(pendingVestingPool > 0);
        require(now - startTime > cliff);

        uint256 gap = now - startTime;
        uint256 intervals = ((gap - (gap % vestingPeriod)) / vestingPeriod);

        if (intervals > 4) {
            intervals = 4;
        }

        uint256 dividendsToVest = ( totalVestingPool / 4 ) * intervals;

        uint256 dividendCat1 = dividendsToVest / 8;
        uint256 dividendCat2 = dividendCat1 * 2;
        
        accounts[founder1].balance += dividendCat2;
        accounts[founder2].balance += dividendCat2;
        accounts[founder3].balance += dividendCat2;
        accounts[founder4].balance += dividendCat1;
        accounts[founder5].balance += dividendCat1;

        accounts[founder2].lastTime = now;
        accounts[founder2].lastTime = now;
        accounts[founder3].lastTime = now;
        accounts[founder4].lastTime = now;
        accounts[founder5].lastTime = now;

        totalSupply_ += dividendsToVest;
        pendingVestingPool -= dividendsToVest;
        pendingInstallments -= intervals;
    }

    // Need to address decimal points
    function dividendsOwed(address owner) private view returns (uint256) {
        uint256 gap = now - accounts[owner].lastTime;

        if (gap < dividendInterval) {
            return 0;
        } else {
            return accounts[owner].balance * (dividendRate**((gap - (gap % dividendInterval)) / (dividendInterval * 10**6)));
        }
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return accounts[_owner].balance + dividendsOwed(_owner);
    }
}