// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint256 subId;
    uint32 callbackGasLimit;

    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant INTIAL_PLAYER_BALANCE = 10 ether;

    /* Events - required for testing by foundry */
    event EnteredRaffle(address indexed player);
    event WinnerAnnounced(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gaslane = config.gaslane;
        subId = config.subId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER, INTIAL_PLAYER_BALANCE);
    }

    /*///////////////////////////////////////////////////////////////////////////////
                        CHECK FOR OPEN STATE AT INTIALIZATION
    ///////////////////////////////////////////////////////////////////////////////*/

    function testRaffleIntializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*///////////////////////////////////////////////////////////////////////////////
                                    ENTER RAFFLE
    ///////////////////////////////////////////////////////////////////////////////*/

    function testRaffleRevertsWhenInsufficientPayment() public {
        // Arrange
        vm.prank(PLAYER);
        // Act/Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testPlayerRecordedWhenEntered() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEmitWhenPlayerEntered() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayersCanNotEnterWhileWinnerIsBeingPicked() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 1 ether}();
        uint256 lastTimeStamp = raffle.getLastTimeStamp();
        vm.warp(lastTimeStamp + interval);
        vm.roll(block.number+1);
        // Act / Assert
        
        raffle.performUpkeep("");
        // Assert
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*///////////////////////////////////////////////////////////////////////////////
                                    CHECK UPKEEP
    ///////////////////////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval);
        vm.roll(block.number+1);
        // Act
        (bool checkUpkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(checkUpkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfWinnerIsBeingPicked() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        // Act
        (bool checkUpkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!checkUpkeepNeeded);
    }

    /*///////////////////////////////////////////////////////////////////////////////
                                    PERFORM UPKEEP
    ///////////////////////////////////////////////////////////////////////////////*/

    function testPerformUpkeepRunsWhenCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        uint256 lastTimeStamp = raffle.getLastTimeStamp();
        vm.warp(lastTimeStamp + interval);
        vm.roll(block.number+1);
        // Act / Assert
        
        raffle.performUpkeep("");
    }

    function testPerformUpkeepFailsWhenCheckUpkeepIsFalse() public {
        // Arrange
        uint256 numPlayers = 1;
        Raffle.RaffleState state = raffle.getRaffleState();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Act/Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, entranceFee, numPlayers, state));
        raffle.performUpkeep("");
    }

    modifier enterRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number+1);
        _;
    }
    function testPerformUpkeepUpdatesRaffleStateAndEmitsEvent() public enterRaffle{
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory enteries = vm.getRecordedLogs();
        bytes32 requestId = enteries[1].topics[1];

        // Assert
        Raffle.RaffleState state = raffle.getRaffleState();
        assert(state == Raffle.RaffleState.FINALIZING);
        assert(uint256(requestId)>0);
    }

    /*///////////////////////////////////////////////////////////////////////////////
                                FULFILL RANDOM WORDS
    ///////////////////////////////////////////////////////////////////////////////*/
    function testFulfillRandomwordsCanOnlyBeCalledAfterPerformUpkeep(uint256 subscriptionId) public enterRaffle {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(subscriptionId, address(raffle));
    }
}