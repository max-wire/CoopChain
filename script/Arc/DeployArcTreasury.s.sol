// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ArcTreasury} from "../../src/sponsors/Arc/ArcTreasury.sol";

contract DeployArcTreasury is Script {
    function run() external returns (ArcTreasury treasury) {
        vm.startBroadcast();

        treasury = new ArcTreasury();

        vm.stopBroadcast();
    }
}
