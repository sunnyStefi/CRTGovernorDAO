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

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract StudentPath is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    enum State {
        SUBSCRIBED,
        ON_HOLD,
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

    mapping(address => uint256) private s_studentToLessonSubscribed; //todo all
    mapping(address => mapping(string => State)) private s_studentLessonsPath;
    mapping(address => mapping(uint256 => CourseState)) private s_studentCoursesPath;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    CourseFactory s_courseFactory;
    uint256[49] __gap;

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
        s_courseFactory = CourseFactory(courseFactory);
    }

    function addCourseAndLessonsToPath(uint256 courseId, address student) private onlyRole(ADMIN) {
        string[] memory courseLessons = s_courseFactory.getAllLessonIds(courseId);
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

    /**
     * Setters
     */
    function setLessonState(address student, uint256 courseId, string memory lessonId, State state)
        public
        onlyRole(ADMIN)
    {
        s_studentLessonsPath[student][lessonId] = state;

        //Set course states
        if (state == State.COMPLETED) {
            s_studentCoursesPath[student][courseId].lessonsCompleted += 1;
        }
        if (state == State.SUBSCRIBED) {
            s_studentCoursesPath[student][courseId].lessonsCompleted -= 1;
        }
        if (state == State.ON_HOLD) {
            s_studentCoursesPath[student][courseId].courseState = State.ON_HOLD;
        }

        
        if (
            s_studentCoursesPath[student][courseId].lessonsSubscribed
                == s_studentCoursesPath[student][courseId].lessonsCompleted
        ) {
            s_studentCoursesPath[student][courseId].courseState = State.COMPLETED;
        } else {
            s_studentCoursesPath[student][courseId].courseState = State.SUBSCRIBED;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
