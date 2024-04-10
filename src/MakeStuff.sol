// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MakeStuff is Ownable {
    uint256 private s_number;

    event NumberChanged();

    constructor() Ownable(_msgSender()) {}

    function store(uint256 number) public onlyOwner {
        s_number = number;
        emit NumberChanged();
    }

    function get() external view returns (uint256) {
        return s_number;
    }
}
