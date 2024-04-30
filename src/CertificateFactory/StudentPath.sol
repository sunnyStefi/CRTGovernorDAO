//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;
//named-imports

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {CourseFactory} from "./CourseFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract StudentPath is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

    enum State {
        EMPTY,
        SUBSCRIBED,
        CURRENTLY_ON_HOLD, //todo just one lesson
        COMPLETED
    }

    enum ExamState {
        FAILED,
        SUCCEEDED
    }

    struct CourseState {
        State courseState;
        uint256 lessonsCompleted;
        uint256 lessonsSubscribed;
    }

    address private s_defaultAdmin;
    uint256 private s_studentPathCounter;
    mapping(address => uint256) private s_courseCompleted;

    mapping(address => uint256) private s_studentToLessonSubscribed; //todo all
    mapping(address => mapping(string => State)) private s_studentLessonsPath;
    mapping(address => mapping(uint256 => CourseState)) private s_studentCoursesPath;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    ERC1967Proxy s_courseFactoryProxy;
    uint256[49] __gap;

    error StudentPath_CoursePathNotInitialized();
    error StudentPath_OnlyOneLessonCanBeOnHold();

    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address upgrader, address courseFactory) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(ADMIN, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));
        _grantRole(ADMIN, defaultAdmin);

        _grantRole(UPGRADER_ROLE, upgrader);

        s_defaultAdmin = defaultAdmin;
        s_studentPathCounter = 0;
        s_courseFactoryProxy = ERC1967Proxy(payable(courseFactory));
    }

    function addCourseAndLessonsToPath(uint256 courseId, address student) public onlyRole(ADMIN) {
        string[] memory courseLessons = CourseFactory(payable(s_courseFactoryProxy)).getAllLessonIds(courseId);
        uint256 allLessonsAmount = courseLessons.length;
        s_studentCoursesPath[student][courseId].courseState = State.SUBSCRIBED;

        s_studentCoursesPath[student][courseId].lessonsCompleted = 0;
        s_studentCoursesPath[student][courseId].lessonsSubscribed = allLessonsAmount;

        for (uint256 i = 0; i < allLessonsAmount; i++) {
            s_studentLessonsPath[student][courseLessons[i]] = State.SUBSCRIBED;
        }
    }

    function submitCourseTestResult(address student, uint256 courseId, ExamState result) public onlyRole(ADMIN) {}

    function submitLessonQuizResult(address student, uint256 courseId, string memory lessonId, ExamState result)
        public
        onlyRole(ADMIN)
    {}

    /**
     * Getters
     */
    function getCourseState(uint256 courseId, address student) public view returns (State) {
        return s_studentCoursesPath[student][courseId].courseState;
    }

    function getLessonCompleted(uint256 courseId, address student) public view returns (uint256) {
        return s_studentCoursesPath[student][courseId].lessonsCompleted;
    }

    function getLessonSubscribed(uint256 courseId, address student) public view returns (uint256) {
        return s_studentCoursesPath[student][courseId].lessonsSubscribed;
    }

    function getLessonState(address student, string memory lessonId) public view returns (State) {
        return s_studentLessonsPath[student][lessonId];
    }

    function getCoursesCompleted(address student) public view returns (uint256) {
        return s_courseCompleted[student];
    }
    /**
     * Setters
     */

    function setLessonState(address student, uint256 courseId, string memory lessonId, State state)
        public
        onlyRole(ADMIN)
    {
        //todo make modifier
        if (s_studentCoursesPath[student][courseId].courseState == State.EMPTY) {
            revert StudentPath_CoursePathNotInitialized();
        }

        s_studentLessonsPath[student][lessonId] = state;

        //Set course states
        if (state == State.COMPLETED) {
            s_studentCoursesPath[student][courseId].lessonsCompleted += 1;
        }
        if (state == State.SUBSCRIBED) {
            s_studentCoursesPath[student][courseId].lessonsCompleted -= 1;
        }
        if (state == State.CURRENTLY_ON_HOLD) {
            s_studentCoursesPath[student][courseId].courseState = State.CURRENTLY_ON_HOLD;
        }

        if (
            s_studentCoursesPath[student][courseId].lessonsSubscribed
                == s_studentCoursesPath[student][courseId].lessonsCompleted
        ) {
            s_studentCoursesPath[student][courseId].courseState = State.COMPLETED;
            s_courseCompleted[student] += 1;
        } else {
            s_studentCoursesPath[student][courseId].courseState = State.SUBSCRIBED;
            s_courseCompleted[student] -= 1;
        }
    }

    function setAllLessonsState(address student, uint256 courseId, State state) public onlyRole(ADMIN) {
        if (s_studentCoursesPath[student][courseId].courseState == State.EMPTY) {
            revert StudentPath_CoursePathNotInitialized();
        }
        
        //Lessons
        string[] memory courseLessons = CourseFactory(payable(s_courseFactoryProxy)).getAllLessonIds(courseId);
        uint256 allLessonsAmount = courseLessons.length;
        for (uint256 i = 0; i < allLessonsAmount; i++) {
            s_studentLessonsPath[student][courseLessons[i]] = state;
        }
        //Courses
        s_studentCoursesPath[student][courseId].courseState = state;
        if (state == State.EMPTY || state == State.SUBSCRIBED) { //check previous state
            s_studentCoursesPath[student][courseId].lessonsCompleted = 0;
            s_studentCoursesPath[student][courseId].lessonsSubscribed = allLessonsAmount;
            s_courseCompleted[student] -= 1;
        }
        if (state == State.COMPLETED) { //check previous state
            s_studentCoursesPath[student][courseId].lessonsCompleted = allLessonsAmount;
            s_studentCoursesPath[student][courseId].lessonsSubscribed = allLessonsAmount;
            s_courseCompleted[student] += 1;
        }
        if (state == State.CURRENTLY_ON_HOLD) {
            revert StudentPath_OnlyOneLessonCanBeOnHold();
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
