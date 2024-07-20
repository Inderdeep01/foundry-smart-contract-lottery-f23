// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

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
}