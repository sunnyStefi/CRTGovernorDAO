// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CourseFactory} from "../src/CertificateFactory/CourseFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CourseFactoryTest is Test {
    address ALICE_ADDRESS_ANVIL = makeAddr("ALICE_ADDRESS_ANVIL");
    string TEST_URI = "ipfs://123";
    string[] TEST_URI_ARRAY = [TEST_URI];
    CourseFactory courseFactory;
    uint256 placesTotal = 10;
    ERC1967Proxy proxy;

    function setUp() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        courseFactory = new CourseFactory();
        bytes memory initializerData =
            abi.encodeWithSelector(CourseFactory.initialize.selector, ALICE_ADDRESS_ANVIL, ALICE_ADDRESS_ANVIL);
        proxy = new ERC1967Proxy(address(courseFactory), initializerData);
        vm.stopPrank();
    }

    function test_createOneCourse() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        CourseFactory(payable(proxy)).createCourse(
            TEST_URI, placesTotal, TEST_URI_ARRAY, TEST_URI, TEST_URI_ARRAY, TEST_URI_ARRAY
        );
        vm.stopPrank();
        vm.assertEq(CourseFactory(payable(proxy)).getCreator(0), ALICE_ADDRESS_ANVIL);
    }

    function test_createMoreCourses() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        vm.stopPrank();
    }
}
