// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CertificantsDAO} from "../src/CertificantsDAO.sol";
import {CRToken} from "../src/CRToken.sol";
import {MakeStuff} from "../src/MakeStuff.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract CertificantsDAOTest is Test {
    TimeLock timelock;
    CRToken crtToken;
    CertificantsDAO governor;
    MakeStuff makeStuff;
    address ALICE_ADDRESS_ANVIL = makeAddr("ALICE_ADDRESS_ANVIL");
    uint256 constant MIN_DELAY = 3600; //after a vote passes /no pass until this goes by
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 50400;
    address[] proposers;
    address[] executors;
    uint256[] values;
    address[] targets;
    bytes[] calldatas;

    function setUp() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        crtToken = new CRToken();
        crtToken.delegate(ALICE_ADDRESS_ANVIL); //msg.sender != ALICE
        governor = new CertificantsDAO(crtToken, timelock, address(crtToken));
        makeStuff = new MakeStuff();

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.revokeRole(ADMIN_ROLE, ALICE_ADDRESS_ANVIL);
        vm.stopPrank();

        makeStuff = new MakeStuff();
        makeStuff.transferOwnership(address(timelock)); //IMP! timelock owns the DAO and viceversa
    }

    function test_boxCannotBeUpdatedByAnyone() public {
        vm.expectRevert();
        makeStuff.store(1);
    }

    function test_governanceUpdatesBox() public {
        // 1. Someone has to Propose to DAO
        uint256 valueToStore = 77;

        string memory description = "Store 77 in makestuff please";
        calldatas.push(abi.encodeWithSignature("store(uint256)", valueToStore));
        values.push(0);
        targets.push(address(makeStuff));

        uint256 propId = governor.propose(targets, values, calldatas, description); //PENDING

        assertEq(uint256(governor.state(propId)), 0);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        assertEq(uint256(governor.state(propId)), 1); //ACTIVE

        // 2. People have to Vote
        uint8 way = 1;

        vm.startPrank(ALICE_ADDRESS_ANVIL);
        governor.castVote(propId, way);
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(propId)), 4); //SUCCEEDED or DEFEATED

        // 3. Queue
        governor.queue(targets, values, calldatas, keccak256(abi.encodePacked(description)));
        vm.roll(block.number + MIN_DELAY + 1);
        vm.warp(block.timestamp + MIN_DELAY + 1);

        assertEq(uint256(governor.state(propId)), 5); //QUEUED

        // //4. Execute
        governor.execute(targets, values, calldatas, keccak256(abi.encodePacked(description)));

        assertEq(uint256(governor.state(propId)), 7); //EXECUTED

        assertEq(makeStuff.get(), valueToStore);
    }
}
