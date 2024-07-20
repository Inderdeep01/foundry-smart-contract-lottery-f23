// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {SubscriptionFactory, ConsumerManager} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {}

    function deployContract() public returns(Raffle, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subId == 0){
            // create a new subscription
            SubscriptionFactory subscriptionFactory = new SubscriptionFactory();
            config.subId = subscriptionFactory.createSubsctiption(config.vrfCoordinator);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(config.entranceFee, config.interval, config.vrfCoordinator, config.gaslane, config.subId, config.callbackGasLimit);
        vm.stopBroadcast();

        ConsumerManager consumerManager = new ConsumerManager();
        consumerManager.addConsumer(config.vrfCoordinator, config.subId, address(raffle));

        return (raffle, helperConfig);
    }
    
}