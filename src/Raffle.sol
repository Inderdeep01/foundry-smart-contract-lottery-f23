// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title A sample Raffle Contract
/// @author Inderdeep Singh
/// @notice This contract is for creating a sample raffle
/// @dev Implements Chainlink VRFv2.5
contract Raffle  is VRFConsumerBaseV2Plus{
    /* Custom Errors */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 players, RaffleState state);

    /* Types */
    enum RaffleState {OPEN, FINALIZING }

    /*Storage Variables */
    /// @notice I tried arraging the state variables to let the solidity compiler do "packing"
    /* Constants */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    /* Immutables */
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_keyhash;
    uint256 private immutable i_entranceFee;
    /// @dev Duration of lottery in seconds
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    
    ///
    uint256 private s_lastTimeStamp;
    RaffleState private s_RaffleState;
    address private s_recentWinner;
    address payable[] private s_players;
    

    /* Events */
    event EnteredRaffle(address indexed player);
    event WinnerAnnounced(address indexed winner);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gaslane, uint256 subId, uint32 callbackGasLimit) 
    VRFConsumerBaseV2Plus(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyhash = gaslane;
        i_subscriptionId = subId;
        i_callbackGasLimit = callbackGasLimit;

    } 

    function enterRaffle() external payable{
        //require(msg.value>=i_entranceFee, "Not enough ETH");
        if (msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        if(s_RaffleState != RaffleState.OPEN){
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /// @dev This is the function that Chainlink Nodes are going to call to check if the winner can be picked
    /// @return upkeepNeeded true if it is time to pick winner
    function checkUpkeep(bytes memory) public view returns(bool upkeepNeeded, bytes memory) {
        bool timePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool lotteryIsOpen = s_RaffleState == RaffleState.OPEN;
        bool hasETH = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timePassed && lotteryIsOpen && hasETH && hasPlayers;
        return (upkeepNeeded,"");
    }

    // Generate Random number to pick player automatically
    function performUpkeep(bytes calldata /* performData */) external {
        // check if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, s_RaffleState);
        }
        s_RaffleState = RaffleState.FINALIZING;
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyhash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false
                    })
                )
            })
        );
    }

    function fulfillRandomWords(uint256 /* requestId */, uint256[] calldata randomWords) internal virtual override{
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_RaffleState = RaffleState.OPEN;
        (bool success,) = recentWinner.call{value:address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
        emit WinnerAnnounced(recentWinner);
    }

    /* Getter Functions */
    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_RaffleState;
    }

    function getPlayer(uint256 index) external view returns(address){
        return s_players[index];
    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }

}