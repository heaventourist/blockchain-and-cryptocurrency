pragma solidity ^0.4.10;

contract DAO {
    uint256 private totalBalance;
    uint256 private breakPointBalance;
    mapping (address => uint256) private balances;
    address[] balanceAddresses;
    address private curator;
    uint256 private valuation;
    bool private unsealedProposal;
    mapping (address => mapping (bool => uint256)) private voteCount;
    address[] private voted;
    struct TotalCount{
        uint256 yes;
        uint256 no;
    }
    TotalCount private totalCount;

    function DAO() public {
        curator = msg.sender;
        totalBalance = 0.0;
        valuation = 1.0;
        unsealedProposal = false;
    }

    function delegateCurator(address newCurator) public {
        require(curator == msg.sender && !unsealedProposal);
        curator = newCurator;
    }

    function deposit() public payable{
        uint256 numTokens = msg.value/valuation;
        totalBalance += numTokens;
        if(unsealedProposal){
            if(voteCount[msg.sender][true]>0) {
                voteCount[msg.sender][true]+=numTokens;
                totalCount.yes += numTokens;
                return;
            }else if(voteCount[msg.sender][false]>0){
                voteCount[msg.sender][false]+=numTokens;
                totalCount.no += numTokens;
                return;
            }
        }
        balances[msg.sender] += numTokens;
        if(!contains(balanceAddresses, msg.sender)){
            balanceAddresses.push(msg.sender);
        }
    }

    function withdraw(uint256 numTokens) public{
        require(numTokens>0 && balances[msg.sender]>=numTokens);
        balances[msg.sender] -= numTokens;
        totalBalance -= numTokens;
        if(!msg.sender.call.value(numTokens*valuation)()){
            throw;
        }
    }

    function getBalance(address addr) public constant returns(uint256){
        return balances[addr];
    }

    function createProposal() public {
        require(curator == msg.sender && !unsealedProposal);
        unsealedProposal = true;
        breakPointBalance = totalBalance / 2;
        resetVote();
    }

    function vote(uint256 numTokens, bool choice) public {
        require(unsealedProposal && !contains(voted, msg.sender));
        voteCount[msg.sender][choice] += numTokens;
        if(!contains(voted, msg.sender)){
            voted.push(msg.sender);
        }
        if(choice){
            totalCount.yes += numTokens;
        }else{
            totalCount.no += numTokens;
        }

        if((totalCount.yes+totalCount.no)>breakPointBalance){
            unsealedProposal = false;
            if(totalCount.yes > totalCount.no){
                valuation *= randomNumber();
            }
            if(valuation == 0){
                resetBalance();
            }else {
                tokenBack();
            }
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
        return uint256(block.blockhash(block.number-1))%10;
    }
}


contract Wallet {
    DAO vulnerableDao;

    function Wallet(address DaoAddress) public {
        vulnerableDao = DAO(DaoAddress);
    }

    function deposit(uint256 amount) constant public {
        vulnerableDao.deposit.value(amount)();
    }

    function withdraw(uint256 numTokens) constant public {
        vulnerableDao.withdraw(numTokens);
    }

    function getDaoBalance() constant public returns (uint256) {
        return vulnerableDao.getBalance(this);
    }

    function getBalance() constant public returns (uint256) {
        return this.balance;
    }

    function createProposal() constant public{
        vulnerableDao.createProposal();
    }

    function vote(uint256 numTokens, bool choice) constant public {
        vulnerableDao.vote(numTokens, choice);
    }
}
