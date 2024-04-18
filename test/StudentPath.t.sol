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

        StudentPath.State actualState =
            StudentPath(payable(studentProxy)).getLessonState(STUDENT_ADDRESS, getLastLessonId());
        assertEq(uint8(actualState), uint8(StudentPath.State.SUBSCRIBED));
    }

    function test_lessonsCompletedAndCourseIncomplete() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);

        StudentPath(payable(studentProxy)).addCourseAndLessonsToPath(randomCourseId, STUDENT_ADDRESS);

        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLessonId(0), StudentPath.State.COMPLETED
        );
        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLastLessonId(), StudentPath.State.COMPLETED
        );
        uint256 actualLessonCompleted =
            StudentPath(payable(studentProxy)).getLessonCompleted(randomCourseId, STUDENT_ADDRESS);
        uint256 expectedLessonCompleted = 2;
        assertEq(actualLessonCompleted, expectedLessonCompleted);

        StudentPath.State actualCourseState =
            StudentPath(payable(studentProxy)).getCourseState(randomCourseId, STUDENT_ADDRESS);
        StudentPath.State expectedCourseState = StudentPath.State.SUBSCRIBED;
        assertEq(uint8(actualCourseState), uint8(expectedCourseState));

        vm.stopPrank();
    }

    function test_lessonsAndCourseCompleted() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);

        StudentPath(payable(studentProxy)).addCourseAndLessonsToPath(randomCourseId, STUDENT_ADDRESS);

        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLessonId(0), StudentPath.State.COMPLETED
        );
        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLessonId(1), StudentPath.State.COMPLETED
        );
        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLastLessonId(), StudentPath.State.COMPLETED
        );

        StudentPath.State actualCourseState =
            StudentPath(payable(studentProxy)).getCourseState(randomCourseId, STUDENT_ADDRESS);
        StudentPath.State expectedCourseState = StudentPath.State.COMPLETED;
        assertEq(uint8(actualCourseState), uint8(expectedCourseState));
        vm.stopPrank();
    }

    function test_lessonsCompleteAndCourseIncompleteWithResubscription() public {
        vm.startPrank(ALICE_ADDRESS_ANVIL);

        StudentPath(payable(studentProxy)).addCourseAndLessonsToPath(randomCourseId, STUDENT_ADDRESS);

        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLessonId(0), StudentPath.State.COMPLETED
        );
        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLessonId(1), StudentPath.State.COMPLETED
        );
        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLessonId(1), StudentPath.State.SUBSCRIBED
        );
        StudentPath(payable(studentProxy)).setLessonState(
            STUDENT_ADDRESS, randomCourseId, getLastLessonId(), StudentPath.State.COMPLETED
        );

        StudentPath.State actualCourseState =
            StudentPath(payable(studentProxy)).getCourseState(randomCourseId, STUDENT_ADDRESS);
        StudentPath.State expectedCourseState = StudentPath.State.SUBSCRIBED;

        assertEq(uint8(actualCourseState), uint8(expectedCourseState));
        uint256 actualLessonCompleted =
            StudentPath(payable(studentProxy)).getLessonCompleted(randomCourseId, STUDENT_ADDRESS);
        uint256 expectedLessonCompleted = 2;
        assertEq(actualLessonCompleted, expectedLessonCompleted);
        vm.stopPrank();
    }

    function getLastLessonId() public view returns (string memory) {
        uint256 lessonLength = CourseFactory(courseProxy).getNumberOfLessons(randomCourseId);
        return string(abi.encodePacked(Strings.toString(randomCourseId), "_", Strings.toString(lessonLength - 1)));
    }

    function getLessonId(uint256 index) public view returns (string memory) {
        return string(abi.encodePacked(Strings.toString(randomCourseId), "_", Strings.toString(index)));
    }
}
