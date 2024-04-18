// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CertificantsDAO} from "../src/DAO/CertificantsDAO.sol";
import {CRToken} from "../src/DAO/CRToken.sol";
import {MakeStuff} from "../src/DAO/MakeStuff.sol";
import {TimeLock} from "../src/DAO/TimeLock.sol";
import {CertificateNFT} from "../src/CertificateFactory/CertificateNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CreateStudentPath} from "../script/Interactions.sol";
import {StudentPath} from "../src/CertificateFactory/StudentPath.sol";

contract CertificateNFTTest is Test {
    TimeLock timelock;
    CRToken crtToken;
    CertificantsDAO governor;
    MakeStuff makeStuff;
    CertificateNFT certificateNFT;
    ERC1967Proxy proxy;
    address studentPathProxy;
    CreateStudentPath createStudentPath;
    address ALICE_ADDRESS_ANVIL = makeAddr("ALICE_ADDRESS_ANVIL");
    address BOB_ADDRESS_ANVIL = makeAddr("BOB_ADDRESS_ANVIL");
    address STUDENT_ADDRESS = makeAddr("STUDENT_ADDRESS");
    uint256 constant MIN_DELAY = 3600; //after a vote passes /no pass until this goes by
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 50400;
    uint256 constant CERTIFICATE_ID_1 = 23534975;
    uint256 constant CERTIFICATE_ID_2 = 34545698;
    uint256 randomCourseId;
    address[] proposers;
    address[] executors;
    uint256[] values;
    address[] targets;
    bytes[] calldatas;

    function setUp() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        vm.deal(ALICE_ADDRESS_ANVIL, 100);

        certificateNFT = new CertificateNFT();
        makeStuff = new MakeStuff();
        createStudentPath = new CreateStudentPath();
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        crtToken = new CRToken(address(proxy));
        governor = new CertificantsDAO(crtToken, timelock);

        (studentPathProxy, randomCourseId) = createStudentPath.run();
        bytes memory initializerData = abi.encodeWithSelector(
            CertificateNFT.initialize.selector, ALICE_ADDRESS_ANVIL, ALICE_ADDRESS_ANVIL, address(studentPathProxy)
        );

        proxy = new ERC1967Proxy(address(certificateNFT), initializerData);

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.revokeRole(ADMIN_ROLE, ALICE_ADDRESS_ANVIL);

        makeStuff.transferOwnership(address(timelock)); //IMP! timelock owns the DAO and viceversa

        StudentPath(payable(studentPathProxy)).setAllLessonsState(
            STUDENT_ADDRESS, randomCourseId, StudentPath.State.COMPLETED
        );
        vm.stopPrank();
    }

    function test_notCertifiedUserCannotMintCrtTokens() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        vm.expectRevert(abi.encodeWithSelector(CRToken.CRToken_OnlyCertificantOwnersCanOwnCRToken.selector));
        crtToken.mint(ALICE_ADDRESS_ANVIL, 1);
        vm.stopPrank();
    }

    function test_certifiedUserCanMintNFT() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        CertificateNFT(payable(proxy)).createCertificate(ALICE_ADDRESS_ANVIL, CERTIFICATE_ID_1, "0x");
        vm.stopPrank();
        crtToken.mint(ALICE_ADDRESS_ANVIL, 1);
        crtToken.delegate(ALICE_ADDRESS_ANVIL);
        assertEq(crtToken.balanceOf(ALICE_ADDRESS_ANVIL), 1);
    }

    function test_certifiedUserCannotMintTooMuchNFT() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        CertificateNFT(payable(proxy)).createCertificate(ALICE_ADDRESS_ANVIL, CERTIFICATE_ID_1, "0x");
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(CRToken.CRToken_AmountOfTokenMintedMustBeLessOrEqualThanCertificatesEarned.selector)
        );
        crtToken.mint(ALICE_ADDRESS_ANVIL, 10);
    }
}
