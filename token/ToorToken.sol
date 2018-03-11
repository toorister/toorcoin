pragma solidity ^0.4.18;


import "./ERC20Basic.sol";


/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract ToorToken is ERC20Basic {
    // TODO LIST
    // Add a function to burn tokens
    // Add Ownable which could allow owner to flip a boolean to turn off reward calculation
    // Add Ownable function to allow owner to change founding team/company ether address
    // Replace currentInterval() with intervalAtTime(now)

    struct Account {
        uint balance;
        uint lastInterval;
    }

    mapping(address => Account) accounts;
    mapping(uint256 => uint256) ratesByYear;
    uint256 private rateMultiplier;

    uint256 initialSupply_;
    uint256 totalSupply_;
    uint256 maxSupply_;
    uint256 startTime;
    uint256 pendingRewardsToMint;

    string public name;
    uint public decimals;
    string public symbol;

    uint256 private tokenGenInterval; // This defines the frequency at which we calculate rewards
    uint256 private vestingPeriod; // Defines how often tokens vest to team
    uint256 private cliff; // Defines the minimum amount of time required before tokens vest
    uint256 private pendingInstallments; // Defines the number of pending vesting installments for team
    uint256 private paidInstallments; // Defines the number of pending vesting installments for team
    uint256 private totalVestingPool; //  Defines total vesting pool set aside for team
    uint256 private pendingVestingPool; // Defines pending tokens in pool set aside for team
    uint256 private finalIntervalForTokenGen; // The last instance of reward calculation, after which rewards will cease
    uint256 private intervalsPerYear; // Total number of times we calculate rewards per year

    // Ether addresses of founders and company
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
        initialSupply_ = 13500000 * 10**18;
        pendingInstallments = 4;
        paidInstallments = 0;
        totalVestingPool = 4500000 * 10**18;
        startTime = now;
        tokenGenInterval = 60;  // This is 1 min in seconds
        uint256 timeToGenAllTokens = 630720000; // 20 years in seconds
        
        accounts[company].balance = (initialSupply_ * 75) / 100; // 75% of initial balance goes to bounty
        accounts[company].lastInterval = 0;
        accounts[bounty].balance = (initialSupply_ * 25) / 100; // 25% of inital balance goes to company expenses
        accounts[bounty].lastInterval = 0;
        pendingVestingPool = totalVestingPool;
        pendingRewardsToMint = maxSupply_ - initialSupply_ - totalVestingPool;
        totalSupply_ = initialSupply_;
        vestingPeriod = timeToGenAllTokens / 80; // One vesting period is a quarter. 80 quarters in 20 years
        cliff = vestingPeriod * 2; // Cliff is two vesting periods aka 6 months roughly
        finalIntervalForTokenGen = timeToGenAllTokens / tokenGenInterval; // This is 7120 days = 20 years. Manually calculated
        intervalsPerYear = finalIntervalForTokenGen / 20;
    }

    // This gives the total supply of actual minted coins. Does not take rewards pending minting into consideration
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }
    
    function allocatedSupply() public view returns (uint256) {
        uint256 totSupply = initialSupply_;
        uint256 currInterval = currentInterval();
        uint256 startInterval = 0;
        uint256 cliffInterval = intervalAtTime(startTime + cliff);
        uint256 cliffVestInterval = intervalAtTime(startTime + cliff + vestingPeriod);

        // Calculate and add rewards specifically for the first year
        totSupply = validate(1, startInterval, currInterval) * totSupply * ((ratesByYear[1] / rateMultiplier) ** getIntervalsForWindow(1, startInterval, currInterval));
        totSupply += validate(1, cliffInterval, currInterval) * (totalVestingPool / 2) * ((ratesByYear[1] / rateMultiplier) ** getIntervalsForWindow(1, cliffInterval, currInterval));
        totSupply += validate(1, cliffVestInterval, currInterval) * (totalVestingPool / 4) * ((ratesByYear[1] / rateMultiplier) ** getIntervalsForWindow(1, cliffVestInterval, currInterval));
        
        // One currInterval is greater than intervalsPerYear, add the final vesting installment
        if (currInterval > intervalsPerYear) {
            totSupply += (totalVestingPool / 4);
        }

        // The second year onwards, there is no increase in token supply through vesting. So simply applying 1 rate for the year will work
        uint256 maxRateWindow = (currInterval / intervalsPerYear) + 1;
        if (maxRateWindow > 20) {
            maxRateWindow = 20; // If you changes this, change TokensOwed function also
        }

        for (uint rateWindow = 2; rateWindow <= maxRateWindow; rateWindow++) {
            totSupply = validate(rateWindow, intervalsPerYear * (rateWindow - 1), currInterval) * totSupply * ((ratesByYear[rateWindow] / rateMultiplier) ** getIntervalsForWindow(rateWindow, intervalsPerYear * (rateWindow - 1), currInterval));
        }

        return totSupply;
    }

    function maxSupply() public view returns (uint256) {
        return maxSupply_;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0)); // Transfer should not be allowed to burn tokens
        require(_value <= balanceOf(msg.sender)); // Sender should have the number of tokens they want to send

        // Distribute rewards tokens first
        addReward(_to);
        addReward(msg.sender);

        accounts[msg.sender].balance -= _value;
        accounts[_to].balance += _value;

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function addReward(address owner) private returns (bool) {
        uint256 tokensToReward = tokensOwed(owner);

        if (tokensToReward > 0) {
            increaseTotalSupply(tokensToReward); // This will break if total supply exceeds max cap. Should never happen though as tokensOwed checks for this condition
            accounts[owner].balance += tokensToReward;
            accounts[owner].lastInterval = currentInterval();
            pendingRewardsToMint -= tokensToReward; // This helps track rounding errors when computing rewards
        }

        return;
    }

    // This function is to vest tokens to the founding team
    function vestTokens() public returns (bool) {
        require(pendingInstallments > 0);
        require(paidInstallments < 4);
        require(pendingVestingPool > 0);
        require(now - startTime > cliff);

        uint256 currInterval = currentInterval();

        // Calculate the pending installments to pay based on current time
        uint256 installments = (currInterval * tokenGenInterval) / vestingPeriod;
        uint256 installmentsToPay = installments - paidInstallments;

        // If there are no installments to pay, stop here
        require (installmentsToPay > 0);

        if (installmentsToPay > pendingInstallments) {
            installmentsToPay = pendingInstallments;
        }

        // Loop through installments to pay, so that we can add token holding rewards as we go along
        for (uint256 installment = 1; installment <= installmentsToPay; installment++) {
            uint256 tokensToVest = totalVestingPool / 4;

            uint256 founderCat1 = tokensToVest / 4;
            uint256 founderCat2 = tokensToVest / 8;

            // If they have rewards pending, allocate those first
            addReward(founder1);
            addReward(founder2);
            addReward(founder3);
            addReward(founder4);
            addReward(founder5);

            // Increase total supply by the number of tokens being vested
            increaseTotalSupply(tokensToVest);
            
            // Vest tokens for each of the founders
            accounts[founder1].balance += founderCat1;
            accounts[founder2].balance += founderCat1;
            accounts[founder3].balance += founderCat1;
            accounts[founder4].balance += founderCat2;
            accounts[founder5].balance += founderCat2;

            // Reduce pendingVestingPool and update pending and paid installments
            pendingVestingPool -= tokensToVest;
            pendingInstallments -= 1;
            paidInstallments += 1;

            // Set last interval to the end of the installment period
            uint256 intervalToSet = (vestingPeriod * paidInstallments) / tokenGenInterval;

            // In case last interval is less than cliff period, see cliff as the last interval. This is to ensure no rewards are paid for pre-cliff vesting periods
            if (intervalToSet < intervalAtTime(cliff)) {
                intervalToSet = intervalAtTime(cliff);
            }

            accounts[founder1].lastInterval = intervalToSet;
            accounts[founder2].lastInterval = intervalToSet;
            accounts[founder3].lastInterval = intervalToSet;
            accounts[founder4].lastInterval = intervalToSet;
            accounts[founder5].lastInterval = intervalToSet;
        }
    }

    function increaseTotalSupply (uint256 tokens) private returns (bool) {
        require ((totalSupply_ + tokens) <= maxSupply_);
        totalSupply_ += tokens;

        return true;
    }

    function tokensOwed(address owner) public view returns (uint256) {
        // Once the specified address has received all possible rewards, don't calculate anything
        if (accounts[owner].lastInterval >= finalIntervalForTokenGen) {
            return 0;
        }

        uint256 tokensHeld = accounts[owner].balance;
        uint256 currInterval = currentInterval();

        uint256 minRateWindow = (accounts[owner].lastInterval / intervalsPerYear) + 1;
        uint256 maxRateWindow = (currInterval / intervalsPerYear) + 1;
        if (maxRateWindow > 20) {
            maxRateWindow = 20;
        }

        // Loop through pending periods of rewards, and calculate the total balance user should hold
        for (uint rateWindow = minRateWindow; rateWindow <= maxRateWindow; rateWindow++) {
            tokensHeld = tokensHeld * ((ratesByYear[rateWindow] / rateMultiplier) ** getIntervalsForWindow(rateWindow, accounts[owner].lastInterval, currInterval));
        }

        // Rewards owed are the total balance that user SHOULD have minus what they currently have
        return (tokensHeld - accounts[owner].balance);
    }

    function currentInterval() private view returns (uint256) {
        return intervalAtTime(now);
    }

    function intervalAtTime(uint256 time) public view returns (uint256) {
        // Check to see that time passed in is not before contract generation time, as that would cause a negative value in the next step
        if (time <= startTime) {
            return 0;
        }

        // Based on time passed in, check how many intervals have elapsed
        return (time - startTime) / tokenGenInterval;
    }

    function validate(uint256 rateWindow, uint256 lastInterval, uint256 currInterval) public view returns (uint256) {
        if ((rateWindow * intervalsPerYear) < lastInterval) {
            return 0; // This means that the window has already been paid for
        } else if (currInterval < ((rateWindow - 1) * intervalsPerYear)) {
            return 0; // This means that we are not at that window yet
        } else {
            return 1;
        }
    }

    // This function checks how many intervals for a given window do we owe tokens to someone for 
    function getIntervalsForWindow(uint256 rateWindow, uint256 lastInterval, uint256 currInterval) public view returns (uint256) {
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

    // This function tells the balance of tokens at a particular address
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return accounts[_owner].balance + tokensOwed(_owner);
    }

    // This functions returns the last time at which rewards were transferred to a particular address
    function lastTimeOf(address _owner) public view returns (uint256 time) {
        return (accounts[_owner].lastInterval * tokenGenInterval) + startTime;
    }
}