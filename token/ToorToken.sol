pragma solidity ^0.4.18;


import "./ERC20Basic.sol";
import "./Ownable.sol";

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract ToorToken is ERC20Basic, Ownable {
    // TODO LIST (NOTHING AT THE MOMENT)
    // allocatedSupply is returning 16.75m instead of 13.5m + rewards
    // Still need to test out transfers
    // After vesting, lastInterval for founders is still set to startTime
    // If after 10 months, vest is run. A founder is paid rewards for 4month (based on time elapsed since 6 month cliff). However, after vesting, lastInterval would be set to 9 month.
    // LastInterval is usually set to now. But when computing rewards, we divide by tokenGenInterval, which can sometimes be a decimal value. Handle this
    // TokenSupply at the moment is actual physical supply. But balances of owner are physical + rewards. That shows up as total amount held by people being greater than total supply on etherscan
    // Reward being paid out at cliff vesting (after the first quarter vesting)

    struct Account {
        uint balance;
        uint lastInterval;
    }

    mapping(address => Account) public accounts;
    mapping(uint256 => uint256) ratesByYear;
    uint256 private rateMultiplier;

    uint256 initialSupply_;
    uint256 totalSupply_;
    uint256 maxSupply_;
    uint256 public startTime;
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
    uint256 public finalIntervalForTokenGen; // The last instance of reward calculation, after which rewards will cease
    uint256 private totalRateWindows; // This specifies the number of rate windows over the total period of time
    uint256 private intervalsPerWindow; // Total number of times we calculate rewards within 1 rate window
    uint256 private intervalsPerBatch; // Defines the number of intervals we compute rewards for at a time

    // Variable to define once reward generation is complete
    bool public rewardGenerationComplete;

    // Ether addresses of founders and company
    address private founder1 = 0xeD20cae0BF1FF4054E1a12bb071d41c95B5C94b5;
    address private founder2 = 0x220Aad0b0bf12fF7245A29cbBA8fcfe72D0dE5d9;
    address private founder3 = 0xc97dfb488407189C5b6d784678b6Dc8516Be88ca;
    address private founder4 = 0x9fD5979af1B5048B05A0e5d8bf2362938C66c1c8;
    address private founder5 = 0x91C3f66A7Bd302DEb55C2ffd0421D48F63DBE011;
    address private company = 0x14278b24e40138822aD75EC740c23e3a99300DBf;
    address private bounty = 0x21445651dD395761544eF1658C5fFd2de7Ca45aC;

    // Events section
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 value);

    function ToorToken() public {
        name = "ToorCoin";
        decimals = 18;
        symbol = "TOOR";

        // Setup the token staking reward percentage per year
        rateMultiplier = 10**14;
        ratesByYear[1] = 1.00066968526012 * 10**14;
        ratesByYear[2] = 1.00046636022513 * 10**14;
        ratesByYear[3] = 1.00039840345596 * 10**14;
        ratesByYear[4] = 1.00034775593764 * 10**14;
        ratesByYear[5] = 1.00030854533529 * 10**14;
        ratesByYear[6] = 1.00027728778505 * 10**14;
        ratesByYear[7] = 1.00025178487441 * 10**14;
        ratesByYear[8] = 1.00023058052456 * 10**14;
        ratesByYear[9] = 1.00021267190991 * 10**14;
        ratesByYear[10] = 1.00019734575885 * 10**14;
        ratesByYear[11] = 1.00018408084667 * 10**14;
        ratesByYear[12] = 1.00017248741666 * 10**14;
        ratesByYear[13] = 1.00016226817746 * 10**14;
        ratesByYear[14] = 1.0001531924111 * 10**14;
        ratesByYear[15] = 1.00014507832187 * 10**14;
        ratesByYear[16] = 1.00013778071947 * 10**14;
        ratesByYear[17] = 1.00013118224552 * 10**14;
        ratesByYear[18] = 1.00012518700852 * 10**14;
        ratesByYear[19] = 1.00011971588938 * 10**14;
        ratesByYear[20] = 1.00011470302747 * 10**14;

        totalRateWindows = 20;
        
        maxSupply_ = 100000000 * 10**18;
        initialSupply_ = 13500000 * 10**18;
        pendingInstallments = 4;
        paidInstallments = 0;
        totalVestingPool = 4500000 * 10**18;
        startTime = now;
        intervalsPerBatch = 3;
        
        // This is for 20 years
        tokenGenInterval = 60;  // This is 1 min in seconds
        uint256 timeToGenAllTokens = 630720000; // 20 years in seconds

        // This is for 20 days
        // tokenGenInterval = 240;  // This is 4 mins
        // uint256 timeToGenAllTokens = 1752000; // roughly 20 days in seconds

        rewardGenerationComplete = false;
        
        // Mint initial tokens
        accounts[company].balance = (initialSupply_ * 75) / 100; // 75% of initial balance goes to bounty
        accounts[company].lastInterval = 0;
        generateMintEvents(company,accounts[company].balance);
        accounts[bounty].balance = (initialSupply_ * 25) / 100; // 25% of inital balance goes to company expenses
        accounts[bounty].lastInterval = 0;
        generateMintEvents(bounty,accounts[bounty].balance);

        pendingVestingPool = totalVestingPool;
        pendingRewardsToMint = maxSupply_ - initialSupply_ - totalVestingPool;
        totalSupply_ = initialSupply_;
        vestingPeriod = timeToGenAllTokens / (totalRateWindows * 4); // One vesting period is a quarter. 80 quarters in 20 years
        cliff = vestingPeriod * 2; // Cliff is two vesting periods aka 6 months roughly
        finalIntervalForTokenGen = timeToGenAllTokens / tokenGenInterval;
        intervalsPerWindow = finalIntervalForTokenGen / totalRateWindows;
    }

    // This gives the total supply of actual minted coins. Does not take rewards pending minting into consideration
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }
    
    function allocatedSupply() public view returns (uint256) {
        uint256 totSupply = initialSupply_;
        uint256 currInterval = intervalAtTime(now);
        uint256 startInterval = 0;
        uint256 cliffInterval = intervalAtTime(startTime + cliff);
        uint256 cliffVestInterval = intervalAtTime(startTime + cliff + vestingPeriod);
        uint256 intPerWind = intervalsPerWindow;

        // Calculate and add rewards specifically for the first year
        totSupply = validate(1, startInterval, currInterval, intPerWind) * totSupply * ((ratesByYear[1] / rateMultiplier) ** getIntervalsForWindow(1, startInterval, currInterval, intPerWind));
        totSupply += validate(1, cliffInterval, currInterval, intPerWind) * (totalVestingPool / 2) * ((ratesByYear[1] / rateMultiplier) ** getIntervalsForWindow(1, cliffInterval, currInterval, intPerWind));
        totSupply += validate(1, cliffVestInterval, currInterval, intPerWind) * (totalVestingPool / 4) * ((ratesByYear[1] / rateMultiplier) ** getIntervalsForWindow(1, cliffVestInterval, currInterval, intPerWind));
        
        // One currInterval is greater than intervalsPerWindow, add the final vesting installment
        if (currInterval > intPerWind) {
            totSupply += (totalVestingPool / 4);
        }

        // The second year onwards, there is no increase in token supply through vesting. So simply applying 1 rate for the year will work
        uint256 maxRateWindow = (currInterval / intPerWind) + 1;
        if (maxRateWindow > totalRateWindows) {
            maxRateWindow = totalRateWindows; // If you changes this, change TokensOwed function also
        }

        for (uint rateWindow = 2; rateWindow <= maxRateWindow; rateWindow++) {
            totSupply = validate(rateWindow, intPerWind * (rateWindow - 1), currInterval, intPerWind) * totSupply * ((ratesByYear[rateWindow] / rateMultiplier) ** getIntervalsForWindow(rateWindow, intPerWind * (rateWindow - 1), currInterval, intPerWind));
        }

        return totSupply;
    }

    function maxSupply() public view returns (uint256) {
        return maxSupply_;
    }

    function transfer(address _to, uint256 _value) canTransfer(_to) public returns (bool) {
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
        if (rewardGenerationComplete) {
            return true;
        }

        uint256 tokensToReward = tokensOwed(owner);

        if (tokensToReward > 0) {
            increaseTotalSupply(tokensToReward); // This will break if total supply exceeds max cap. Should never happen though as tokensOwed checks for this condition
            accounts[owner].balance += tokensToReward;
            accounts[owner].lastInterval = intervalAtTime(now);
            pendingRewardsToMint -= tokensToReward; // This helps track rounding errors when computing rewards
            generateMintEvents(owner, tokensToReward);
        }

        return true;
    }

    // This function is to vest tokens to the founding team
    function vestTokens() public returns (bool) {
        require(pendingInstallments > 0);
        require(paidInstallments < 4);
        require(pendingVestingPool > 0);
        require(now - startTime > cliff);

        uint256 currInterval = intervalAtTime(now);

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

            // In case last interval is less than cliff period, set cliff as the last interval. This is to ensure no rewards are paid for pre-cliff vesting periods
            if (intervalToSet < intervalAtTime(cliff)) {
                intervalToSet = intervalAtTime(cliff);
            }

            accounts[founder1].lastInterval = intervalToSet;
            accounts[founder2].lastInterval = intervalToSet;
            accounts[founder3].lastInterval = intervalToSet;
            accounts[founder4].lastInterval = intervalToSet;
            accounts[founder5].lastInterval = intervalToSet;

            // Create events for token generation
            generateMintEvents(founder1, founderCat1);
            generateMintEvents(founder2, founderCat1);
            generateMintEvents(founder3, founderCat1);
            generateMintEvents(founder4, founderCat2);
            generateMintEvents(founder5, founderCat2);
        }
    }

    function increaseTotalSupply (uint256 tokens) private returns (bool) {
        require ((totalSupply_ + tokens) <= maxSupply_);
        totalSupply_ += tokens;

        return true;
    }

    function tokensOwed(address owner) public view returns (uint256) {
        uint256 lastInt = accounts[owner].lastInterval;
        // Once the specified address has received all possible rewards, don't calculate anything
        if (lastInt >= finalIntervalForTokenGen) {
            return 0;
        }

        uint256 bal = accounts[owner].balance;
        uint256 tokensHeld = bal;
        uint256 intPerWin = intervalsPerWindow;
        uint256 totalRateWinds = totalRateWindows;
        uint256 currInterval = intervalAtTime(now);
        uint256 intPerBatch = intervalsPerBatch;
        mapping(uint256 => uint256) ratByYear = ratesByYear;
        uint256 ratMultiplier = rateMultiplier;

        uint256 minRateWindow = (lastInt / intPerWin) + 1;
        uint256 maxRateWindow = (currInterval / intPerWin) + 1;
        if (maxRateWindow > totalRateWinds) {
            maxRateWindow = totalRateWinds;
        }

        // Loop through pending periods of rewards, and calculate the total balance user should hold
        for (uint256 rateWindow = minRateWindow; rateWindow <= maxRateWindow; rateWindow++) {
            uint256 intervals = getIntervalsForWindow(rateWindow, lastInt, currInterval, intPerWin);

            // This part is to ensure we don't overflow when rewards are pending for a large number of intervals
            // Loop through interval in batches
            while (intervals > 0) {
                if (intervals >= intPerBatch) {
                    tokensHeld = (tokensHeld * (ratByYear[rateWindow] ** intPerBatch)) / (ratMultiplier ** intPerBatch);
                    intervals -= intPerBatch;
                } else {
                    tokensHeld = (tokensHeld * (ratByYear[rateWindow] ** intervals)) / (ratMultiplier ** intervals);
                    intervals = 0;
                }
            }            
        }

        // Rewards owed are the total balance that user SHOULD have minus what they currently have
        return (tokensHeld - bal);
    }

    function minMaxWindows(address owner) public view returns (uint256 min, uint256 max) {
        uint256 minRateWindow = (accounts[owner].lastInterval / intervalsPerWindow) + 1;
        uint256 maxRateWindow = (intervalAtTime(now) / intervalsPerWindow) + 1;

        return (minRateWindow, maxRateWindow);
    }

    function intervalAtTime(uint256 time) public view returns (uint256) {
        // Check to see that time passed in is not before contract generation time, as that would cause a negative value in the next step
        if (time <= startTime) {
            return 0;
        }

        // Based on time passed in, check how many intervals have elapsed
        return (time - startTime) / tokenGenInterval;
    }

    function validate(uint256 rateWindow, uint256 lastInterval, uint256 currInterval, uint256 intPerWind) public view returns (uint256) {
        if ((rateWindow * intPerWind) < lastInterval) {
            return 0; // This means that the window has already been paid for
        } else if (currInterval < ((rateWindow - 1) * intPerWind)) {
            return 0; // This means that we are not at that window yet
        } else {
            return 1;
        }
    }

    // This function checks how many intervals for a given window do we owe tokens to someone for 
    function getIntervalsForWindow(uint256 rateWindow, uint256 lastInterval, uint256 currInterval, uint256 intPerWind) public view returns (uint256) {
        // If lastInterval for holder falls in a window previous to current one, the lastInterval for the window passed into the function would be the window start interval
        if (lastInterval < ((rateWindow - 1) * intPerWind)) {
            lastInterval = ((rateWindow - 1) * intPerWind);
        }

        // If currentInterval for holder falls in a window higher than current one, the currentInterval for the window passed into the function would be the window end interval
        if (currInterval > rateWindow * intPerWind) {
            currInterval = rateWindow * intPerWind;
        }

        return currInterval - lastInterval;
    }

    // This function tells the balance of tokens at a particular address
    function balanceOf(address _owner) public view returns (uint256 balance) {
        if (rewardGenerationComplete) {
            return accounts[_owner].balance;
        } else {
            return accounts[_owner].balance + tokensOwed(_owner);
        }
    }

    function balanceOfBasic(address _owner) public view returns (uint256 balance) {
        return accounts[_owner].balance;
    }

    // This functions returns the last time at which rewards were transferred to a particular address
    function lastTimeOf(address _owner) public view returns (uint256 interval, uint256 time) {
        return (accounts[_owner].lastInterval, (accounts[_owner].lastInterval * tokenGenInterval) + startTime);
    }

    // This function is not meant to be used. It's only written as a fail-safe against potential unforeseen issues
    function mint(address _to, uint256 _amount) onlyOwner public returns (bool) {
        increaseTotalSupply(_amount);
        accounts[_to].balance += _amount;
        generateMintEvents(_to, _amount);
        return true;
    }

    function generateMintEvents(address _to, uint256 _amount) private returns (bool) {
        Mint(_to, _amount);
        Transfer(address(0), _to, _amount);

        return true;
    }

    // Allows the burning of tokens
    function burn(uint256 _value) public {
        require(_value <= accounts[msg.sender].balance);

        address burner = msg.sender;
        accounts[burner].balance -= _value;
        totalSupply_ -= _value;
        Burn(burner, _value);
        Transfer(burner, address(0), _value);
    }

    // These set of functions allow changing of founder and company addresses
    function setFounder1(address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        founder1 = _to;
        return true;
    }

    function setFounder2(address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        founder2 = _to;
        return true;
    }

    function setFounder3(address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        founder3 = _to;
        return true;
    }

    function setFounder4(address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        founder4 = _to;
        return true;
    }

    function setFounder5(address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        founder5 = _to;
        return true;
    }

    function setCompany(address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        company = _to;
        return true;
    }

    function setBounty(address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        bounty = _to;
        return true;
    }

    function getTeamAddresses() onlyOwner public view returns (address, address, address, address, address, address, address) {
        return (founder1, founder2, founder3, founder4, founder5, company, bounty);
    }

    // This is a setter for rewardGenerationComplete. It will be used to see if token rewards need to be computed, and can only be set by owner
    function setRewardGenerationComplete(bool _value) onlyOwner public returns (bool) {
        rewardGenerationComplete = _value;
        return true;
    }

    // This function is added to get a state of where the token is in term of reward generation
    function getNow() public view returns (uint256, uint256) {
        return (now, block.number);
    }

    // This modifier is used on the transfer method and defines where tokens CANNOT be sent
    modifier canTransfer(address _to) {
        require(_to != address(0)); // Transfer should not be allowed to burn tokens
        // This is to ensure that no tokens can be transferred to founder accounts, as that would corrupt reward calculation
        require((_to != founder1) && (_to != founder2) && (_to != founder3) && (_to != founder4) && (_to != founder5)); 
        _;
    }
}