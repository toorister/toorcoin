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
        uint lastInterval;
    }

    mapping(address => Account) accounts;
    mapping(uint256 => uint256) ratesByYear;
    uint256 private rateMultiplier;

    uint256 totalSupply_;
    uint256 maxSupply_;
    uint256 startTime;
    //uint256 pendingDividendsToGenerate;

    string public name;
    uint public decimals;
    string public symbol;

    uint256 private tokenGenInterval;
    uint256 private maxNoOfDividendPayouts;
    uint256 private vestingPeriod;
    uint256 private cliff;
    uint256 private pendingInstallments;
    uint256 private totalVestingPool;
    uint256 private pendingVestingPool;
    uint256 private finalIntervalForTokenGen;
    uint256 private intervalsPerYear;
    uint256 private timeToGenAllTokens;
    address private founder1 = 0xeD20cae0BF1FF4054E1a12bb071d41c95B5C94b5;
    address private founder2 = 0x220Aad0b0bf12fF7245A29cbBA8fcfe72D0dE5d9;
    address private founder3 = 0xc97dfb488407189C5b6d784678b6Dc8516Be88ca;
    address private founder4 = 0x9fD5979af1B5048B05A0e5d8bf2362938C66c1c8;
    address private founder5 = 0x91C3f66A7Bd302DEb55C2ffd0421D48F63DBE011;
    address private company = 0x14278b24e40138822aD75EC740c23e3a99300DBf;
    address private bounty = 0x21445651dD395761544eF1658C5fFd2de7Ca45aC;

    function ToorToken() public {
        name = "ToorCoin";
        decimals = 18;
        symbol = "TOOR";

        // Setup the token staking reward percentage per year
        rateMultiplier = 10**14;
        ratesByYear[1] = 1.00000046490366 * 10**14;
        ratesByYear[2] = 1.00000032378583 * 10**14;
        ratesByYear[3] = 1.00000027661401 * 10**14;
        ratesByYear[4] = 1.00000024145523 * 10**14;
        ratesByYear[5] = 1.00000021423457 * 10**14;
        ratesByYear[6] = 1.00000019253429 * 10**14;
        ratesByYear[7] = 1.00000017482861 * 10**14;
        ratesByYear[8] = 1.00000016010692 * 10**14;
        ratesByYear[9] = 1.00000014767313 * 10**14;
        ratesByYear[10] = 1.00000013703215 * 10**14;
        ratesByYear[11] = 1.00000012782217 * 10**14;
        ratesByYear[12] = 1.00000011977261 * 10**14;
        ratesByYear[13] = 1.00000011267710 * 10**14;
        ratesByYear[14] = 1.00000010637548 * 10**14;
        ratesByYear[15] = 1.00000010074153 * 10**14;
        ratesByYear[16] = 1.00000009567447 * 10**14;
        ratesByYear[17] = 1.00000009109281 * 10**14;
        ratesByYear[18] = 1.00000008692999 * 10**14;
        ratesByYear[19] = 1.00000008313106 * 10**14;
        ratesByYear[20] = 1.00000007965032 * 10**14;
        
        maxSupply_ = 100000000 * 10**18;
        totalSupply_ = 13500000 * 10**18;
        timeToGenAllTokens = 630720000; // 20 years in seconds
        tokenGenInterval = 60;  // This is 1 min in seconds
        pendingInstallments = 4;
        totalVestingPool = 4500000 * 10**18;
        startTime = now;

        accounts[company].balance = (totalSupply_ * 75) / 100; // 75% of initial balance goes to bounty
        accounts[company].lastInterval = 0;
        accounts[bounty].balance = (totalSupply_ * 25) / 100; // 25% of inital balance goes to company expenses
        accounts[bounty].lastInterval = 0;
        pendingVestingPool = totalVestingPool;
        //pendingDividendsToGenerate = maxSupply_ - totalSupply_ - totalVestingPool;
        vestingPeriod = timeToGenAllTokens / 80; // One vesting period is a quarter. 80 quarters in 20 years
        cliff = vestingPeriod * 2; // Cliff is two vesting periods aka 6 months roughly
        finalIntervalForTokenGen = timeToGenAllTokens / tokenGenInterval; // This is 7120 days = 20 years. Manually calculated
        intervalsPerYear = finalIntervalForTokenGen / 20;
    }

    /**
    * @dev total number of tokens in existence
    */
    // TODO: ADD MINTED TOKENS TO THIS CALCULATION
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

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function addDividends(address owner) private returns (bool) {
        if (tokensOwed(owner) > 0) {
            accounts[owner].balance += tokensOwed(owner);
            accounts[owner].lastInterval = currentInterval();
        }

        return;
    }

    // TODO: FIX TOKEN VESTING ACCORDING TO NEW INTERVAL SCHEME
    function vestTokens() public returns (bool) {
        require(pendingInstallments > 0);
        require(pendingVestingPool > 0);
        require(now - startTime > cliff);

        //uint256 gap = now - startTime;
        uint256 intervals = currentInterval();

        if (intervals > 4) {
            intervals = 4;
        }

        uint256 tokensToVest = ( totalVestingPool / 4 ) * intervals;

        uint256 founderCat1 = tokensToVest / 8;
        uint256 founderCat2 = founderCat1 * 2;
        
        accounts[founder1].balance += founderCat2;
        accounts[founder2].balance += founderCat2;
        accounts[founder3].balance += founderCat2;
        accounts[founder4].balance += founderCat1;
        accounts[founder5].balance += founderCat1;

        accounts[founder2].lastInterval = currentInterval();
        accounts[founder2].lastInterval = currentInterval();
        accounts[founder3].lastInterval = currentInterval();
        accounts[founder4].lastInterval = currentInterval();
        accounts[founder5].lastInterval = currentInterval();

        totalSupply_ += tokensToVest;
        pendingVestingPool -= tokensToVest;
        pendingInstallments -= intervals;
    }

    // Need to address decimal points
    function tokensOwed(address owner) private view returns (uint256) {
        if (accounts[owner].lastInterval >= finalIntervalForTokenGen) {
            return 0;
        }

        uint256 tokensPending = 0;
        uint256 currInterval = currentInterval();

        for (uint rateWindow = 1; rateWindow <= 20; rateWindow++) {
            tokensPending += validate(rateWindow, accounts[owner].lastInterval, currInterval) * accounts[owner].balance * ((ratesByYear[rateWindow] / rateMultiplier) ** getIntervalsForWindow(rateWindow, accounts[owner].lastInterval, currInterval));
        }

        return tokensPending;
    }

    function currentInterval() private view returns (uint256) {
        return (now - startTime) / tokenGenInterval;
    }

    function validate(uint256 rateWindow, uint256 lastInterval, uint256 currInterval) private view returns (uint256) {
        if ((rateWindow * intervalsPerYear) < lastInterval) {
            return 0; // This means that the window has already been paid for
        } else if (currInterval < ((rateWindow - 1) * intervalsPerYear)) {
            return 0; // This means that we are not at that window yet
        } else {
            return 1;
        }
    }

    // This function checks how many intervals for a given window do we owe tokens to someone for 
    function getIntervalsForWindow(uint256 rateWindow, uint256 lastInterval, uint256 currInterval) private view returns (uint256) {
        // If lastInterval for holder falls in a window previous to current one, the lastInterval for the window passed into the function would be the window start interval
        if (lastInterval < ((rateWindow - 1) * intervalsPerYear)) {
            lastInterval = ((rateWindow - 1) * intervalsPerYear);
        }

        // If currentInterval for holder falls in a window higher than current one, the currentInterval for the window passed into the function would be the window end interval
        if (currInterval < rateWindow * intervalsPerYear) {
            currInterval = rateWindow * intervalsPerYear;
        }

        return currInterval - lastInterval;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return accounts[_owner].balance + tokensOwed(_owner);
    }
}