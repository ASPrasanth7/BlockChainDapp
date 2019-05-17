pragma solidity ^0.5.0;

contract NewGame {
     address payable developer;
    //Struct to hold player details
    struct Player{
        address payable player;
        uint guessNum;
        uint bet;
    }
    //table count for each round of play (optional)
    uint tablecount;
    //developer's address to receive commision

    //event to track player count in front end
    event player_count_event(uint bet,uint count,address addr);

    event totalwinamoubt(address[playSize] adr,uint256[playSize] winamount);
    //Player pool size as per requirement size = 10
    uint constant public playSize=4;
    //Event to track history of transactions with player details
    event playerdetails_event(address[playSize] adr,uint[playSize] guessnums,uint[playSize] winPercent,uint count,uint bet);
    //Player struct array to hold players details
    Player[] public players;
    //mapping with different bet size i,e 50,100,500,10 each represent 0.05,0.1,0.5,0.01 eth.
    mapping (uint => Player[]) pools;

    constructor() public{
      //Initialize table count to 0
      tablecount = 0;
      developer = msg.sender;
    }

    //Function called while player placing bet
    function joinGame(address payable adr,uint guessnum, uint bet) public payable{
        //initialize struct
        Player memory p1 = Player(address(0),0,0);

        p1.player = adr;
        p1.guessNum = guessnum;
        p1.bet = bet;
        //Check for play size to enter the pool
         if(pools[bet].length < playSize){
            //push the player to mapped bet
             pools[bet].push(p1);
             //emitting the player count event
            emit player_count_event(bet,pools[bet].length,adr);
            //If player count reaches the pool size call the calculation
             if(pools[bet].length == playSize){
                distributeReward(bet);
            }
        }else{
            delete players;
        }
    }

    //get player address as array by sending bet value
    function getPlayerAddress(uint bet) public view returns (address[playSize] memory,uint){
        address[playSize] memory addrarray;
        if(pools[bet].length != 0){
            for(uint i=0;i<pools[bet].length;i++){
                addrarray[i] = pools[bet][i].player;
            }
            return (addrarray,bet);
        }
    }
    //pool check from frontend
    function checkPoolcheck(uint bet_val) public view returns(bool){
      if (bet_val == 100 || bet_val == 500 || bet_val == 10 || bet_val == 50){
        return true;
      }else{
        return false;
      }
    }
    //Checking the duplicate address in the pool restricting user is already bet is placed
    function checkDuplicate(address adr,uint bet) public view returns(bool){
        for(uint i=0; i<pools[bet].length; i++){
            if(adr == pools[bet][i].player){
                return true;
            }else{
                return false;
            }
        }
    }

    //To get contract balance
    function getContractBal() public view returns (uint256){
        return address(this).balance;
    }

  //reward distribution function
  function distributeReward(uint bet) public{ //function distributeReward(bet) public{
    //Pool size must be filled and player count must be equal to playsize
      if(pools[bet].length == playSize){

          address[playSize] memory adr;
        uint[playSize] memory winAmount;

        //Contract balance must be greater than winning rewards
           if(address(this).balance >= calcTotalether(bet)){
             //To get win percentage of all the players of the pool
              uint[playSize] memory rewards = magicmagic(bet);
              for(uint i = 0;i<rewards.length; i++){
                //Transfer based on the percentage and bet amount of the pool
                 adr[i] = pools[bet][i].player;
                 winAmount[i] = rewards[i]*10000000;
                 pools[bet][i].player.transfer(rewards[i]*10000000);
              }
              emit totalwinamoubt(adr,winAmount);
              uint total_ether = calcTotalether(bet); //
            uint commision = (total_ether*10)/100;
              //transfer to developer
              developer.transfer(commision*1000000000000000);
              //emit bet and bet length for live tracking in front end
              //emit player_count_event(bet,pools[bet].length,);
              delete pools[bet];

          }
      }
  }

    function magicmagic(uint bet) public returns(uint[playSize] memory) {
        //Total ether
        uint total_ether = calcTotalether(bet); //
        //commision
        uint commision = (total_ether*10)/100;
        //Reward for players to split
        uint total_rewards = total_ether - commision;
        //Sum of guess numbers of the players in the pool
        uint guessSum = calculateSum(bet);
        //Guess average of the players in the pool i.e mean of the numbers
        uint guessAvg =  guessSum*100/pools[bet].length;
        //Deviation from mean of each player's guess number
        uint[playSize] memory deviateValue = calcDeviate(guessAvg,bet);
        //Deviation average calculation
        uint deviateAvg = sumDeviate(deviateValue)/pools[bet].length;
        //Windeviation of each player's guess number
        uint[playSize] memory winDeviation = deviatedValues(guessAvg,deviateAvg,deviateValue);
        //Percentage calculation of the win Deviation
        uint[playSize] memory winpercentage = winpercentage(winDeviation,guessAvg,bet);
        //Price distribution with total rewards
        uint[playSize] memory priceDistribution = priceDistribution(total_rewards,winpercentage,bet);
        return priceDistribution;
    }

    function priceDistribution(uint total_rewards,uint[playSize]memory winpercentage,uint bet) public returns(uint[playSize] memory){
        uint[playSize] memory result;
        for(uint i=0;i<winpercentage.length;i++){
            result[i] = ((total_rewards*100/pools[bet].length) * winpercentage[i] *100);
        }
        return result;
    }
    function winpercentage(uint[playSize] memory winDeviation,uint guessAvg,uint bet) public returns (uint[playSize] memory){
      address[playSize] memory adr;
      uint[playSize] memory guessnums;
        uint[playSize] memory result;

        tablecount++;

        for(uint i=0;i<winDeviation.length;i++){
            result[i] = winDeviation[i]*100*100/guessAvg;
            adr[i] = pools[bet][i].player;
            guessnums[i] = pools[bet][i].guessNum;
        }
        //Player details event emiiting to capture in frontend
        emit playerdetails_event(adr,guessnums,result,tablecount,bet);
        return result;
    }
    function deviatedValues(uint avg,uint deviateAvg,uint[playSize] memory deviateValue) public view returns(uint[playSize] memory){
        uint[playSize] memory result;
        for(uint i=0;i<deviateValue.length;i++){
            result[i] = avg + deviateAvg - deviateValue[i];
        }
        return result;
    }

    function sumDeviate(uint[playSize] memory deviate) public view returns(uint){
        uint sum = 0;
        for(uint i=0;i<deviate.length;i++){
            sum = sum + deviate[i];
        }
        return sum;
    }
    function calcDeviate(uint guessAvg,uint bet) public view returns(uint[playSize] memory){
        uint[playSize] memory result;
        if(pools[bet].length == playSize){
            for(uint i=0;i<pools[bet].length;i++){
              //nearest mean deviation for each player's guess value
                if(pools[bet][i].guessNum*100 > guessAvg){
                    uint temp = pools[bet][i].guessNum*100-guessAvg;
                    result[i] = temp;
                }else if(pools[bet][i].guessNum*100 < guessAvg ){
                    uint temp = guessAvg - pools[bet][i].guessNum*100;
                    result[i] = temp;
                }else{
                    uint temp = 0;
                    result[i] = temp;
                }
            }
        }
        return result;
    }

    function calcTotalether(uint bet) public view returns(uint){
        uint sum = 0;
        if(pools[bet].length == playSize){
            for(uint i=0;i<pools[bet].length;i++){
                sum = sum + pools[bet][i].bet;
            }
        }
        return sum;
    }

    function calculateSum(uint bet) public view returns(uint){
        uint sum = 0;
        if(pools[bet].length == playSize){
            for(uint i=0;i<pools[bet].length;i++){
                sum = sum + pools[bet][i].guessNum;
            }
        }
        return sum;
    }
}
