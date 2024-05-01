// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CourseFactory} from "../src/CertificateFactory/CourseFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract CourseFactoryTest is Test {
    address ALICE_ADDRESS_ANVIL = makeAddr("ALICE_ADDRESS_ANVIL");
    string TEST_URI = "ipfs://123";
    string[] TEST_URI_ARRAY = [TEST_URI];
    string[] TEST_LESSON_URI_ARRAY = [TEST_URI, TEST_URI, TEST_URI]; //3 lessons
    CourseFactory courseFactory;
    uint256 placesTotal = 10;
    ERC1967Proxy proxy;
    VRFCoordinatorV2Mock vrfCoordinatorV2Mock;
    uint96 baseFee = 0.25 ether;
    uint32 callbackgaslimit = type(uint32).max;
    uint96 gasPriceLink = 1e9; //1gwei LINK
    CourseFactory.CourseStruct createdCourse;

    function setUp() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        vm.deal(ALICE_ADDRESS_ANVIL, 5 ether);
        vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        courseFactory = new CourseFactory(address(vrfCoordinatorV2Mock));
        uint64 subscriptionId = vrfCoordinatorV2Mock.createSubscription();
        vrfCoordinatorV2Mock.fundSubscription(subscriptionId, 3 ether);

        bytes memory initializerData = abi.encodeWithSelector(
            CourseFactory.initialize.selector,
            ALICE_ADDRESS_ANVIL,
            ALICE_ADDRESS_ANVIL,
            address(vrfCoordinatorV2Mock),
            bytes32("0x"),
            subscriptionId,
            uint32(callbackgaslimit)
        );
        proxy = new ERC1967Proxy(address(courseFactory), initializerData);
        vrfCoordinatorV2Mock.addConsumer(subscriptionId, address(proxy));

        vm.stopPrank();
    }

    function test_createOneCourse() public {
        uint256 requestId = test_createCourse();
        uint256 randomWord = receiveRandomWord(requestId);
        assertEq(randomWord, CourseFactory(payable(proxy)).getLastRandomNumber());
    }

    function test_lessonsIdsCreatedWithRandomNumber() public {
        uint256 requestId = test_createCourse();
        uint256 randomWord = receiveRandomWord(requestId);
        string memory actualResult = CourseFactory(payable(proxy)).getLessonId(randomWord, 2); //lessons start from index 0
        string memory expectedResult = string(abi.encodePacked(Strings.toString(randomWord), "_2"));
        assertEq(abi.encodePacked(actualResult), abi.encodePacked(expectedResult));
    }

    function test_createCourse() public returns (uint256) {
        vm.startPrank(ALICE_ADDRESS_ANVIL);

        uint256 requestIdResult;
        vm.recordLogs();
        (createdCourse, requestIdResult) = CourseFactory(payable(proxy)).createCourse(
            TEST_URI, placesTotal, TEST_URI, TEST_LESSON_URI_ARRAY, TEST_LESSON_URI_ARRAY
        ); //emit requestId
        vm.stopPrank();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[1].topics.length, 2);
        assertEq(entries[1].topics[0], keccak256("CourseFactory_CertificateCreatedAndRequestSent(uint256)"));
        return uint256(entries[1].topics[1]);
    }

    //Pretending to be chainlink VRF
    function receiveRandomWord(uint256 requestId) public returns (uint256) {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        vm.recordLogs();
        vrfCoordinatorV2Mock.fulfillRandomWords(uint256(requestId), address(proxy));
        vm.stopPrank();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // assertEq(entries[0].topics.length, 2);
        // assertEq(entries[0].topics[0], keccak256("RandomWordsFulfilled(uint256,uint256,uint96,bool)"));
        return uint256(entries[0].topics[1]);
    }
}
