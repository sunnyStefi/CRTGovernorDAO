//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;
//named-imports

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/vrf/VRFConsumerBaseV2.sol";

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract CourseFactory is Initializable, AccessControlUpgradeable, UUPSUpgradeable, VRFConsumerBaseV2 {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    enum State {
        OPEN,
        PENDING
    }

    struct CourseStruct {
        //0. others
        address creator;
        bool isOpen;
        string uri;
        //1. places
        uint256 placesTotal;
        uint256 placesAvailable;
        //2. certification
        string certificationUri;
        //3. section
        //3.1 lessons
        //3.1.1 quiz
        string[] lessonsIds;  //"XYZ.._0, XYZ.._1, .."
        string[] lessonsUris;
        string[] quizUris;
    }

    uint16 private REQUEST_CONFIRMATIONS = 3;
    uint32 private NUM_WORDS; //do not assign variables here (proxy)
    uint32 private s_callbackgaslimit;
    uint64 private s_subscriptionId;
    uint256 s_lastRandomNumber;
    uint256 s_courseIdCounter;
    address private s_defaultAdmin;
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 private s_gasLane;
    mapping(uint256 => CourseStruct) private s_idToCourse;
    State private s_currentRequestState;
    CourseStruct s_createdCourse;
    VRFCoordinatorV2Interface private s_vrfCoordinator;

    event CourseFactory_CourseIdReceived(uint256 indexed id);
    event CourseFactory_CertificateCreatedAndRequestSent(uint256 indexed id);
    event CourseFactory_DefaultRolesAssigned();
    event NumberOfLessons(uint256 indexed num);

    error CourseFactory_IncorrectState();
    error CourseFactory_CourseAlreadyExists();
    error CourseFactory_EachLessonMustHaveOneQuiz();

    uint256[49] __gap;

    constructor(address vrfCoordinator) VRFConsumerBaseV2(vrfCoordinator) {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address upgrader,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackgaslimit
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(ADMIN, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));
        _grantRole(ADMIN, defaultAdmin);

        _grantRole(UPGRADER_ROLE, upgrader);

        s_defaultAdmin = defaultAdmin;
        s_courseIdCounter = 0;
        NUM_WORDS = 1;

        //VRF params - chain dependent addresses
        s_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        s_gasLane = gasLane;
        s_subscriptionId = subscriptionId;
        s_callbackgaslimit = callbackgaslimit;
        s_currentRequestState = State.OPEN;
        emit CourseFactory_DefaultRolesAssigned();
    }

    /* 
     *  Step 1: create course and request random id
     */
    function createCourse(
        string memory uri,
        uint256 _placesTotal,
        string memory _certificationUri,
        string[] memory _lessonsUris,
        string[] memory _quizUris
    ) public onlyRole(ADMIN) returns (CourseStruct memory, uint256 requestId) {
        if (_lessonsUris.length != _quizUris.length) {
            revert CourseFactory_EachLessonMustHaveOneQuiz();
        }
        if (s_currentRequestState != State.OPEN) {
            revert CourseFactory_IncorrectState();
        }
        s_currentRequestState = State.PENDING;
        (, s_courseIdCounter) = s_courseIdCounter.tryAdd(1);
        string[] memory emptyArray = new string[](0);
        s_createdCourse = CourseStruct(
            _msgSender(),
            true,
            uri,
            _placesTotal,
            _placesTotal,
            _certificationUri,
            emptyArray,
            _lessonsUris,
            _quizUris
        );

        uint256 reqId = s_vrfCoordinator.requestRandomWords(
            s_gasLane, s_subscriptionId, REQUEST_CONFIRMATIONS, s_callbackgaslimit, NUM_WORDS
        );

        emit CourseFactory_CertificateCreatedAndRequestSent(reqId);

        return (s_createdCourse, reqId);
    }
    
    /**
     * VRF Callback
     * - receiving random words
     * - use it as index for mapping courses and lessons
     */

    function fulfillRandomWords(uint256, /*requestId*/ uint256[] memory randomWords) internal override {
        if (s_currentRequestState != State.PENDING) {
            revert CourseFactory_IncorrectState();
        }
        uint256 courseId = randomWords[0] % type(uint256).max;
        s_lastRandomNumber = courseId;
        emit CourseFactory_CourseIdReceived(courseId);

        //set lessons unique ids COURSE-ID-RANDOM_LESSON-NUMBER
        uint256 numberOfLessons = getNumberOfLessons(s_createdCourse);
        string[] memory lessonsIds = new string[](numberOfLessons);
        for (uint256 i = 0; i < numberOfLessons; i++) {
            lessonsIds[i] = string(abi.encodePacked(Strings.toString(courseId), "_", Strings.toString(i)));
        }
        s_createdCourse.lessonsIds = lessonsIds;

        s_idToCourse[courseId] = s_createdCourse;
        //reset fields
        string[] memory emptyArrayStr = new string[](0);
        s_createdCourse =
            CourseStruct(address(0), false, "", 0, 0, "", emptyArrayStr, emptyArrayStr, emptyArrayStr);

        s_currentRequestState = State.OPEN;
    }

    function removeCourse(uint256 courseId) public onlyRole(ADMIN) returns (bool) {
        s_idToCourse[courseId].creator = address(0);
        s_idToCourse[courseId].isOpen = false;
        //..todo
    }

    /**
     * Getters
     */
    //course counter starts from 1
    function getIdCounter() public view returns (uint256) {
        return s_courseIdCounter;
    }

    function getCourse(uint256 id) public view returns (CourseStruct memory) {
        return s_idToCourse[id];
    }

    function getCreator(uint256 id) public view returns (address) {
        return s_idToCourse[id].creator;
    }

    function getNumberOfLessons(CourseStruct memory course) public pure returns (uint256) {
        return course.lessonsUris.length;
    }

    function getLessonId(uint256 courseId, uint256 lessonIndex) public view returns (string memory) {
        return s_idToCourse[courseId].lessonsIds[lessonIndex];
    }

    function getNumberOfLessons(uint256 courseId) public view returns (uint256) {
        return s_idToCourse[courseId].lessonsIds.length;
    }

    function getLastRandomNumber() public view returns (uint256) {
        return s_lastRandomNumber;
    }

    function getAllLessonIds(uint256 courseId) public view returns (string[] memory) {
        return s_idToCourse[courseId].lessonsIds;
    }

    function getAvailablePlaces(uint256 courseId) public view returns (uint256) {
        return s_idToCourse[courseId].placesAvailable;
    }

    function isAdmin(address user) public view returns (bool) {
        return hasRole(ADMIN, user);
    }

    /**
     * Setters
     */

    function decrementAvailablePlaces(uint256 courseId) public view returns (uint256) { //todo onlyRole(ADMIN)
        return s_idToCourse[courseId].placesAvailable -1;
    }
    function closeCourse() public {}

    function openCourse() public {}
    
    // PROXY
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
