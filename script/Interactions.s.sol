// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract SubscriptionFactory is Script {
    function createSubscriptionUsingConfig() public returns(uint256 subId, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        subId = createSubsctiption(vrfCoordinator);
        return(subId, vrfCoordinator);
    }

    function createSubsctiption(address vrfCoordinator) public returns(uint256){
        console.log("Creating subscrioption for chainId", block.chainid);

        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Created Subscription with id", subId);
        return(subId);
    }


    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract SubcriptionManager is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 1 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subId;
        address link = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subId, link);
    }

    function fundSubscription(address vrfCoordinator, uint256 subId, address link) public {
        console.log("Funding subscription", subId);

        if(block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT*300);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() public{
        fundSubscriptionUsingConfig();
    }
}

contract ConsumerManager is Script, CodeConstants {
    function run() public{
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentDeployment);
    }

    function addConsumerUsingConfig(address mostRecentDeployment) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subId;
        addConsumer(vrfCoordinator, subId, mostRecentDeployment);
    }

    function addConsumer(address vrfCoordinator, uint256 subId, address consumer) public {
        console.log("Adding Conumer", consumer);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();

        
        console.log("Consumer added Successfully");
    }
}