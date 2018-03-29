pragma solidity ^0.4.18;


import "./ERC20Basic.sol";
import "./Ownable.sol";

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract ToorToken is ERC20Basic, Ownable {
    // TODO LIST (NOTHING AT THE MOMENT)
    // Still need to test out transfers
    // TokenSupply at the moment is actual physical supply. But balances of owner are physical + rewards. That shows up as total amount held by people being greater than total supply on etherscan
    // Too many tokens being given out for vesting runs after 65 intervals (2.5m+ for founderCat1)

    struct Account {
        uint balance;
        uint lastInterval;
    }

    mapping(address => Account) public accounts;
    mapping(uint256 => uint256) ratesByYear;
    uint256 private rateMultiplier;

    uint256 initialSupply_;
    uint256 totalSupply_;
    uint256 public maxSupply;
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

    // Variable to define once reward generation is complete
    bool public rewardGenerationComplete;

    // Ether addresses of founders and company
    mapping(uint256 => address) public distributionAddresses;

    // Events section
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 value);

    function ToorToken() public {
        name = "ToorCoin";
        decimals = 18;
        symbol = "TOOR";

        // Setup the token staking reward percentage per year
        rateMultiplier = 10**14;
        ratesByYear[1] = 1.00466125247859 * 10**14;
        ratesByYear[2] = 1.00327808818413 * 10**14;
        ratesByYear[3] = 1.00279984113421 * 10**14;
        ratesByYear[4] = 1.00244353542178 * 10**14;
        ratesByYear[5] = 1.00216776307204 * 10**14;
        ratesByYear[6] = 1.00194797199061 * 10**14;
        ratesByYear[7] = 1.00176867594624 * 10**14;
        ratesByYear[8] = 1.00161962151688 * 10**14;
        ratesByYear[9] = 1.00149374903201 * 10**14;
        ratesByYear[10] = 1.00138603842211 * 10**14;
        ratesByYear[11] = 1.00129282200637 * 10**14;
        ratesByYear[12] = 1.00121135767832 * 10**14;
        ratesByYear[13] = 1.00113955418154 * 10**14;
        ratesByYear[14] = 1.00107578877672 * 10**14;
        ratesByYear[15] = 1.00101878296575 * 10**14;
        ratesByYear[16] = 1.00096751578847 * 10**14;
        ratesByYear[17] = 1.00092116207264 * 10**14;
        ratesByYear[18] = 1.00087904764088 * 10**14;
        ratesByYear[19] = 1.00084061627889 * 10**14;
        ratesByYear[20] = 1.00080540501263 * 10**14;

        totalRateWindows = 20;
        
        maxSupply = 100000000 * 10**18;
        initialSupply_ = 13500000 * 10**18;
        pendingInstallments = 6;
        paidInstallments = 0;
        totalVestingPool = 4500000 * 10**18;
        startTime = now;

        distributionAddresses[1] = 0xeD20cae0BF1FF4054E1a12bb071d41c95B5C94b5; // founder 1
        distributionAddresses[2] = 0x220Aad0b0bf12fF7245A29cbBA8fcfe72D0dE5d9; // founder 2
        distributionAddresses[3] = 0xc97dfb488407189C5b6d784678b6Dc8516Be88ca; // founder 3
        distributionAddresses[4] = 0x9fD5979af1B5048B05A0e5d8bf2362938C66c1c8; // founder 4
        distributionAddresses[5] = 0x91C3f66A7Bd302DEb55C2ffd0421D48F63DBE011; // founder 5
        distributionAddresses[6] = 0x14278b24e40138822aD75EC740c23e3a99300DBf; // company
        distributionAddresses[7] = 0x21445651dD395761544eF1658C5fFd2de7Ca45aC; // bounty
        
        // This is for 20 years
        // tokenGenInterval = 603936;  // This is roughly 1 week in seconds
        // uint256 timeToGenAllTokens = 628093440; // This is close to 20 years in seconds

        // This is for 5.7 hours
        tokenGenInterval = 60;
        uint256 timeToGenAllTokens = 62400;

        rewardGenerationComplete = false;
        
        // Mint initial tokens
        accounts[distributionAddresses[6]].balance = (initialSupply_ * 60) / 100; // 60% of initial balance goes to Company
        accounts[distributionAddresses[6]].lastInterval = 0;
        generateMintEvents(distributionAddresses[6],accounts[distributionAddresses[6]].balance);
        accounts[distributionAddresses[7]].balance = (initialSupply_ * 40) / 100; // 40% of inital balance goes to Bounty
        accounts[distributionAddresses[7]].lastInterval = 0;
        generateMintEvents(distributionAddresses[7],accounts[distributionAddresses[7]].balance);

        pendingVestingPool = totalVestingPool;
        pendingRewardsToMint = maxSupply - initialSupply_ - totalVestingPool;
        totalSupply_ = initialSupply_;
        vestingPeriod = timeToGenAllTokens / (totalRateWindows * 12); // One vesting period is a quarter. 80 quarters in 20 years
        cliff = vestingPeriod * 6; // Cliff is two vesting periods aka 6 months roughly
        finalIntervalForTokenGen = timeToGenAllTokens / tokenGenInterval;
        intervalsPerWindow = finalIntervalForTokenGen / totalRateWindows;
    }

    // This gives the total supply of actual minted coins. Does not take rewards pending minting into consideration
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }
    
    function allocatedSupply() public view returns (uint256) {
        uint256 totSupply = initialSupply_;
        uint256 vestingPerMonth = (totalVestingPool * 15) / 100;
        uint256 currInterval = intervalAtTime(now);
        uint256 cliffInterval = intervalAtTime(startTime + cliff);

        // This adds reward tokens rewarded for initial supply until now
        totSupply += tokensOwedByInterval(initialSupply_, 0, currInterval);

        // This adds tokens rewarded for tokens vesting on cliff onwards
        if (now >= cliff) {
            totSupply += (vestingPerMonth * 6);
            totSupply += tokensOwedByInterval((vestingPerMonth * 6), cliffInterval, currInterval);
        }

        // This adds the token rewards for tokens vesting after the cliff onwards
        for (uint256 installment = 1; installment <= 5; installment++) {
            if (now >= (startTime + cliff + (installment * vestingPeriod))) {
                totSupply += vestingPerMonth;
                totSupply += tokensOwedByInterval(vestingPerMonth, intervalAtTime(startTime + cliff + (installment * vestingPeriod)), currInterval);
            }
        }

        return totSupply;
    }

    function transfer(address _to, uint256 _value) canTransfer(_to) public returns (bool) {
        uint256 tokensOwedSender = 0;
        uint256 tokensOwedReceiver = 0;
        uint256 balSender = balanceOfBasic(msg.sender);

        // Distribute rewards tokens first
        if (!rewardGenerationComplete) {
            tokensOwedSender = tokensOwed(msg.sender);
            require(_value <= (balSender + tokensOwedSender)); // Sender should have the number of tokens they want to send

            tokensOwedReceiver = tokensOwed(_to);

            // If there were tokens owed, increase total supply accordingly
            if ((tokensOwedSender + tokensOwedReceiver) > 0) {
                increaseTotalSupply(tokensOwedSender + tokensOwedReceiver); // This will break if total exceeds max cap
                pendingRewardsToMint -= (tokensOwedSender + tokensOwedReceiver);
            }

            // If there were tokens owed, raise mint events for them
            raiseEventIfMinted(msg.sender, tokensOwedSender);
            raiseEventIfMinted(_to, tokensOwedReceiver);
        } else {
            require(_value <= balSender);
        }
        
        // Update balances of sender and receiver
        accounts[msg.sender].balance = balSender + tokensOwedSender - _value;
        accounts[_to].balance += (tokensOwedReceiver + _value);

        // Update last intervals for sender and receiver
        uint256 currInt = intervalAtTime(now);
        accounts[msg.sender].lastInterval = currInt;
        accounts[_to].lastInterval = currInt;

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function raiseEventIfMinted(address owner, uint256 tokensToReward) private returns (bool) {
        if (tokensToReward > 0) {
            generateMintEvents(owner, tokensToReward);
        }
    }

    function addReward(address owner) private returns (bool) {
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
        require(paidInstallments < 6);
        require(pendingVestingPool > 0);
        require(now - startTime > cliff);

        // If they have rewards pending, allocate those first
        if (!rewardGenerationComplete) {
            for (uint256 i = 1; i <= 5; i++) {
                addReward(distributionAddresses[i]);
            }
        }

        uint256 currInterval = intervalAtTime(now);
        uint256 tokensToVest = 0;
        uint256 totalTokensToVest = 0;
        uint256 totalPool = totalVestingPool;

        uint256[2] memory founderCat;
        founderCat[0] = 0;
        founderCat[1] = 0;

        uint256[5] memory origFounderBal;
        origFounderBal[0] = accounts[distributionAddresses[1]].balance;
        origFounderBal[1] = accounts[distributionAddresses[2]].balance;
        origFounderBal[2] = accounts[distributionAddresses[3]].balance;
        origFounderBal[3] = accounts[distributionAddresses[4]].balance;
        origFounderBal[4] = accounts[distributionAddresses[5]].balance;

        uint256[2] memory rewardCat;
        rewardCat[0] = 0;
        rewardCat[1] = 0;

        // Pay out cliff
        if (paidInstallments < 1) {
            uint256 intervalAtCliff = intervalAtTime(cliff);
            tokensToVest = totalPool / 4;

            founderCat[0] = tokensToVest / 4;
            founderCat[1] = tokensToVest / 8;

            // This condition checks if there are any rewards to pay after the cliff
            if (currInterval > intervalAtCliff && !rewardGenerationComplete) {
                rewardCat[0] = tokensOwedByInterval(founderCat[0], intervalAtCliff, currInterval);
                rewardCat[1] = tokensOwedByInterval(founderCat[1], intervalAtCliff, currInterval);

                // Add rewards to founder tokens being vested
                founderCat[0] += rewardCat[0];
                founderCat[1] += rewardCat[1];

                // Increase total amount of tokens to vest
                tokensToVest += ((3 * rewardCat[0]) + (2 * rewardCat[1]));
            }

            // Vest tokens for each of the founders, this includes any rewards pending since cliff passed
            accounts[distributionAddresses[1]].balance += founderCat[0];
            accounts[distributionAddresses[2]].balance += founderCat[0];
            accounts[distributionAddresses[3]].balance += founderCat[0];
            accounts[distributionAddresses[4]].balance += founderCat[1];
            accounts[distributionAddresses[5]].balance += founderCat[1];

            totalTokensToVest = tokensToVest;

            // Update pending and paid installments
            pendingInstallments -= 1;
            paidInstallments += 1;
        }

        // Calculate the pending non-cliff installments to pay based on current time
        uint256 installments = ((currInterval * tokenGenInterval) - cliff) / vestingPeriod;
        uint256 installmentsToPay = installments + 1 - paidInstallments;

        // If there are no installments to pay, skip this
        if (installmentsToPay > 0) {
            if (installmentsToPay > pendingInstallments) {
                installmentsToPay = pendingInstallments;
            }

            tokensToVest = (totalPool * 15) / 100;

            founderCat[0] = tokensToVest / 4;
            founderCat[1] = tokensToVest / 8;

            uint256 intervalsAtVest = 0;

            // Loop through installments to pay, so that we can add token holding rewards as we go along
            for (uint256 installment = 1; installment <= installmentsToPay; installment++) {
                intervalsAtVest = intervalAtTime(cliff + (installment * vestingPeriod));

                // This condition checks if there are any rewards to pay after the cliff
                if (currInterval > intervalsAtVest && !rewardGenerationComplete) {
                    rewardCat[0] = tokensOwedByInterval(founderCat[0], intervalsAtVest, currInterval);
                    rewardCat[1] = tokensOwedByInterval(founderCat[1], intervalsAtVest, currInterval);

                    // Add rewards to founder tokens being vested
                    founderCat[0] += rewardCat[0];
                    founderCat[1] += rewardCat[1];

                    // Increase total amount of tokens to vest
                    totalTokensToVest += tokensToVest;
                    totalTokensToVest += ((3 * rewardCat[0]) + (2 * rewardCat[1]));

                    // Vest tokens for each of the founders, this includes any rewards pending since vest interval passed
                    accounts[distributionAddresses[1]].balance += founderCat[0];
                    accounts[distributionAddresses[2]].balance += founderCat[0];
                    accounts[distributionAddresses[3]].balance += founderCat[0];
                    accounts[distributionAddresses[4]].balance += founderCat[1];
                    accounts[distributionAddresses[5]].balance += founderCat[1];
                }
            }

            pendingInstallments -= installmentsToPay;
            paidInstallments += installmentsToPay;
        }

        // Increase total supply by the number of tokens being vested
        increaseTotalSupply(totalTokensToVest);
            
        // Reduce pendingVestingPool and update pending and paid installments
        pendingVestingPool -= totalTokensToVest;

        accounts[distributionAddresses[1]].lastInterval = currInterval;
        accounts[distributionAddresses[2]].lastInterval = currInterval;
        accounts[distributionAddresses[3]].lastInterval = currInterval;
        accounts[distributionAddresses[4]].lastInterval = currInterval;
        accounts[distributionAddresses[5]].lastInterval = currInterval;

        // Create events for token generation
        generateMintEvents(distributionAddresses[1], (accounts[distributionAddresses[1]].balance - origFounderBal[0]));
        generateMintEvents(distributionAddresses[2], (accounts[distributionAddresses[2]].balance - origFounderBal[1]));
        generateMintEvents(distributionAddresses[3], (accounts[distributionAddresses[3]].balance - origFounderBal[2]));
        generateMintEvents(distributionAddresses[4], (accounts[distributionAddresses[4]].balance - origFounderBal[3]));
        generateMintEvents(distributionAddresses[5], (accounts[distributionAddresses[5]].balance - origFounderBal[4]));
    }

    function increaseTotalSupply (uint256 tokens) private returns (bool) {
        require ((totalSupply_ + tokens) <= maxSupply);
        totalSupply_ += tokens;

        return true;
    }

    function tokensOwed(address owner) public view returns (uint256) {
        // This array is introduced to circumvent stack depth issues
        uint256 currInterval = intervalAtTime(now);
        uint256 lastInterval = accounts[owner].lastInterval;
        uint256 balance = accounts[owner].balance;

        return tokensOwedByInterval(balance, lastInterval, currInterval);
    }

    function tokensOwedByInterval(uint256 balance, uint256 lastInterval, uint256 currInterval) public view returns (uint256) {
        // Once the specified address has received all possible rewards, don't calculate anything
        if (lastInterval >= currInterval || lastInterval >= finalIntervalForTokenGen) {
            return 0;
        }

        uint256 tokensHeld = balance; //tokensHeld
        uint256 intPerWin = intervalsPerWindow;
        uint256 totalRateWinds = totalRateWindows;

        // Defines the number of intervals we compute rewards for at a time
        uint256 intPerBatch = 3; // Hardcoded here instead of storing on blockchain to save gas

        mapping(uint256 => uint256) ratByYear = ratesByYear;
        uint256 ratMultiplier = rateMultiplier;

        uint256 minRateWindow = (lastInterval / intPerWin) + 1;
        uint256 maxRateWindow = (currInterval / intPerWin) + 1;
        if (maxRateWindow > totalRateWinds) {
            maxRateWindow = totalRateWinds;
        }

        // Loop through pending periods of rewards, and calculate the total balance user should hold
        for (uint256 rateWindow = minRateWindow; rateWindow <= maxRateWindow; rateWindow++) {
            uint256 intervals = getIntervalsForWindow(rateWindow, lastInterval, currInterval, intPerWin);

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
        return (tokensHeld - balance);
    }

    function intervalAtTime(uint256 time) public view returns (uint256) {
        // Check to see that time passed in is not before contract generation time, as that would cause a negative value in the next step
        if (time <= startTime) {
            return 0;
        }

        // Based on time passed in, check how many intervals have elapsed
        uint256 interval = (time - startTime) / tokenGenInterval;
        uint256 finalInt = finalIntervalForTokenGen; // Assign to local to reduce gas
        
        // Return max intervals if it's greater than that time
        if (interval > finalInt) {
            return finalInt;
        } else {
            return interval;
        }
    }

    // This function checks how many intervals for a given window do we owe tokens to someone for 
    function getIntervalsForWindow(uint256 rateWindow, uint256 lastInterval, uint256 currInterval, uint256 intPerWind) public pure returns (uint256) {
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
    function setFounder(uint256 id, address _to) onlyOwner public returns (bool) {
        require(_to != address(0));
        distributionAddresses[id] = _to;
        return true;
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
        _;
    }
}