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
        SHORT_TERM_QUIZ_PASSED,
        DAILY_TERM_QUIZ_PASSED,
        WEEKLY_TERM_QUIZ_PASSED,
        COMPLETED
    }

    struct CourseState {
        State courseState;
        uint256 lessonsCompleted;
        uint256 lessonsSubscribed;
    }

    uint256 private s_studentPathCounter;
    address private s_defaultAdmin;
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    mapping(address => uint256) private s_courseCompleted;
    mapping(address => uint256) private s_studentToLessonSubscribed;
    mapping(address => mapping(uint256 => CourseState)) private s_studentCoursesPath;
    mapping(address => mapping(string => State)) private s_studentLessonsPath;
    ERC1967Proxy s_courseFactoryProxy;
    uint256[49] __gap;

    error StudentPath_CoursePathNotInitialized();
    error StudentPath_OnlyOneLessonCanBeOnHold();
    error StudentPath_StateOrderNotCongruentWithStateFlow(State currentState, State newState);

    modifier checkState(State currentState, State newState) {
        if (currentState >= newState) {
            revert StudentPath_StateOrderNotCongruentWithStateFlow(currentState, newState);
        }
        _;
    }

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
        checkState(s_studentCoursesPath[student][courseId].courseState, state)
        onlyRole(ADMIN)
    {
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

        if (
            s_studentCoursesPath[student][courseId].lessonsSubscribed
                == s_studentCoursesPath[student][courseId].lessonsCompleted
        ) {
            s_studentCoursesPath[student][courseId].courseState = State.COMPLETED;
            s_courseCompleted[student] += 1;
        } else {
            s_studentCoursesPath[student][courseId].courseState = State.SUBSCRIBED;
            if (s_courseCompleted[student] != 0) {
                s_courseCompleted[student] -= 1;
            }
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
        if (state == State.EMPTY || state == State.SUBSCRIBED) {
            //check previous state
            s_studentCoursesPath[student][courseId].lessonsCompleted = 0;
            s_studentCoursesPath[student][courseId].lessonsSubscribed = allLessonsAmount;
            s_courseCompleted[student] -= 1;
        }
        if (state == State.COMPLETED) {
            //check previous state
            s_studentCoursesPath[student][courseId].lessonsCompleted = allLessonsAmount;
            s_studentCoursesPath[student][courseId].lessonsSubscribed = allLessonsAmount;
            s_courseCompleted[student] += 1;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
