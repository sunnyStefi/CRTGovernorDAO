// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CertificantsDAO} from "../src/DAO/CertificantsDAO.sol";
import {CRToken} from "../src/DAO/CRToken.sol";
import {MakeStuff} from "../src/DAO/MakeStuff.sol";
import {TimeLock} from "../src/DAO/TimeLock.sol";
import {CertificateNFT} from "../src/CertificateFactory/CertificateNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StudentPath} from "../src/CertificateFactory/StudentPath.sol";
import {CreateStudentPath} from "../script/Interactions.sol";

contract CertificantsDAOTest is Test {
    TimeLock timelock;
    CRToken crtToken;
    CertificantsDAO governor;
    MakeStuff makeStuff;
    CertificateNFT certificateNFT;
    CreateStudentPath createStudentPath;
    ERC1967Proxy proxy;
    address ALICE_ADDRESS_ANVIL = makeAddr("ALICE_ADDRESS_ANVIL");
    address STUDENT_ADDRESS = makeAddr("STUDENT_ADDRESS_ANVIL");
    address courseProxy;
    address studentProxy;
    uint256 randomCourseId;
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
        vm.deal(ALICE_ADDRESS_ANVIL, 100);

        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        certificateNFT = new CertificateNFT();
        createStudentPath = new CreateStudentPath();
        (studentProxy, randomCourseId) = createStudentPath.run();
        bytes memory initializerDataCertificate = abi.encodeWithSelector(
            CertificateNFT.initialize.selector, ALICE_ADDRESS_ANVIL, ALICE_ADDRESS_ANVIL, studentProxy
        );
        StudentPath(payable(studentProxy)).addCourseAndLessonsToPath(randomCourseId, STUDENT_ADDRESS);
        StudentPath(payable(studentProxy)).setAllLessonsState(
            STUDENT_ADDRESS, randomCourseId, StudentPath.State.COMPLETED
        );
        proxy = new ERC1967Proxy(address(certificateNFT), initializerDataCertificate);
        crtToken = new CRToken(address(proxy));
        governor = new CertificantsDAO(crtToken, timelock);
        makeStuff = new MakeStuff();

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.revokeRole(ADMIN_ROLE, ALICE_ADDRESS_ANVIL);

        //certificate needed first
        CertificateNFT(payable(proxy)).createCertificate(STUDENT_ADDRESS, 123, "0x");
        crtToken.mint(STUDENT_ADDRESS, 1);
        crtToken.delegate(STUDENT_ADDRESS);
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

        uint256 propId = governor.propose(targets, values, calldatas, description);

        assertEq(uint256(governor.state(propId)), 0); //PENDING

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(governor.state(propId)), 1); //after some VOTING DELAY >> ACTIVE

        // 2. People with certificates can vote
        uint8 way = 1;
        console.log("Balance");
        console.log(crtToken.balanceOf(STUDENT_ADDRESS));

        vm.startPrank(STUDENT_ADDRESS);
        governor.castVote(propId, way);
        vm.stopPrank();

        vm.roll(block.number + VOTING_PERIOD + 1);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(propId)), 4); //SUCCEEDED 4 or DEFEATED 3

        // 3. Queue
        governor.queue(targets, values, calldatas, keccak256(abi.encodePacked(description)));
        vm.roll(block.number + MIN_DELAY + 1);
        vm.warp(block.timestamp + MIN_DELAY + 1);

        assertEq(uint256(governor.state(propId)), 5); //QUEUED

        // 4. Execute
        governor.execute(targets, values, calldatas, keccak256(abi.encodePacked(description)));

        assertEq(uint256(governor.state(propId)), 7); //EXECUTED
        assertEq(makeStuff.get(), valueToStore);
    }
}
