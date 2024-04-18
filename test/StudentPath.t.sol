// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {CreateCourse} from "../script/Interactions.sol";
import {StudentPath} from "../src/CertificateFactory/StudentPath.sol";
import {CourseFactory} from "../src/CertificateFactory/CourseFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract StudenPathTest is Test {
    address ALICE_ADDRESS_ANVIL = makeAddr("ALICE_ADDRESS_ANVIL");
    address STUDENT_ADDRESS = makeAddr("STUDENT_ADDRESS");
    CreateCourse createCourse;
    StudentPath studentPath;
    address courseProxy;
    uint256 randomCourseId;
    ERC1967Proxy studentProxy;

    function setUp() public {
        vm.deal(ALICE_ADDRESS_ANVIL, 5 ether);
        createCourse = new CreateCourse();
        studentPath = new StudentPath();
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        (courseProxy, randomCourseId) = createCourse.run();
        bytes memory initializerData = abi.encodeWithSelector(
            StudentPath.initialize.selector, ALICE_ADDRESS_ANVIL, ALICE_ADDRESS_ANVIL, address(courseProxy)
        );
        studentProxy = new ERC1967Proxy(address(studentPath), initializerData);
        vm.stopPrank();
    }

    function test_addCourseAndLessonsToPath() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);
        StudentPath(payable(studentProxy)).addCourseAndLessonsToPath(randomCourseId, STUDENT_ADDRESS);
        vm.stopPrank();
        uint256 lessonLength = CourseFactory(courseProxy).getNumberOfLessons(randomCourseId);
        string memory lastLessonId =
            string(abi.encodePacked(Strings.toString(randomCourseId), "_", Strings.toString(lessonLength - 1)));

        StudentPath.State actualState = StudentPath(payable(studentProxy)).getLessonState(STUDENT_ADDRESS, lastLessonId);
        assertEq(uint8(actualState), uint8(StudentPath.State.INIT));
    }
}
