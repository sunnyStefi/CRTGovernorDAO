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
    enum State {
        OPEN,
        PENDING
    }

    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    uint16 private REQUEST_CONFIRMATIONS = 3;
    uint32 private NUM_WORDS = 1;
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    VRFCoordinatorV2Interface private s_vrfCoordinator;
    bytes32 private s_gasLane;
    uint64 private s_subscriptionId;
    uint32 private s_callbackgaslimit;
    State private s_randomIdsRequest;
    CourseStruct s_createdCourse;

    event CourseFactory_CourseIdReceived(uint256 indexed id);
    event CourseFactory_CertificateCreatedAndRequestSent(uint256 indexed id);
    event CourseFactory_DefaultRolesAssigned();

    error CourseFactory_CourseAlreadyExists();
    error CourseFactory_EachLessonMustHaveOneQuiz();
    error RequestNotOpen();

    address private s_defaultAdmin;

    uint256 s_courseIdCounter;
    mapping(uint256 => CourseStruct) private s_idToCourse;

    uint256[49] __gap;

    struct CourseStruct {
        //0. others
        address creator;
        bool isOpen;
        string uri;
        //1. places
        uint256 placesTotal;
        uint256 placesAvailable;
        //2. test
        string[] testsUris;
        //3. certification
        string certificationUri;
        //4. sections -- not consider for now
        //4.1 lessons
        //4.1.1 quiz
        uint256[] lessonsIds;
        string[] lessonsUris;
        string[] quizUris;
    }

    constructor(address vrfCoordinator) VRFConsumerBaseV2(vrfCoordinator) {
        //to check
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

        //VRF params - chain dependent addresses
        s_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        s_gasLane = gasLane;
        s_subscriptionId = subscriptionId;
        s_callbackgaslimit = callbackgaslimit;
        s_randomIdsRequest = State.OPEN;
        emit CourseFactory_DefaultRolesAssigned();
    }

    /* 
     *  Step 1: create course and request random id
     */
    function createCourse(
        string memory uri,
        uint256 _placesTotal,
        string[] memory _testsUris,
        string memory _certificationUri,
        string[] memory _lessonsUris,
        string[] memory _quizUris
    ) public onlyRole(ADMIN) returns (CourseStruct memory, uint256 requestId) {
        if (_lessonsUris.length != _quizUris.length) {
            revert CourseFactory_EachLessonMustHaveOneQuiz();
        }
        if (s_randomIdsRequest != State.OPEN) {
            revert RequestNotOpen();
        }
        s_randomIdsRequest = State.PENDING;
        (, s_courseIdCounter) = s_courseIdCounter.tryAdd(1);
        uint256[] memory lessonsIds = new uint256[](_lessonsUris.length);

        for (uint256 i = 0; i < _lessonsUris.length; i++) {
            lessonsIds[i] = i;
        }

        s_createdCourse = CourseStruct(
            _msgSender(),
            true,
            uri,
            _placesTotal,
            _placesTotal,
            _testsUris,
            _certificationUri,
            lessonsIds,
            _lessonsUris,
            _quizUris
        );

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            s_gasLane, s_subscriptionId, REQUEST_CONFIRMATIONS, s_callbackgaslimit, NUM_WORDS
        );

        emit CourseFactory_CertificateCreatedAndRequestSent(requestId);

        return (s_createdCourse, requestId);
    }
    /**
     * Create Course after receiving random words (VRF callback function)
     *
     */

    function fulfillRandomWords(uint256, /*requestId*/ uint256[] memory randomWords) internal override {
        uint256 courseId = randomWords[0];
        s_idToCourse[courseId] = s_createdCourse;
        emit CourseFactory_CourseIdReceived(courseId);

        //reset fields
        string[] memory emptyArrayStr = new string[](0);
        uint256[] memory emptyArrayUint = new uint256[](0);
        s_createdCourse =
            CourseStruct(address(0), false, "", 0, 0, emptyArrayStr, "", emptyArrayUint, emptyArrayStr, emptyArrayStr);
        s_randomIdsRequest = State.OPEN;
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

    function isAdmin(address user) public view returns (bool) {
        return hasRole(ADMIN, user);
    }

    /**
     * Setters
     */
    function closeCourse() public {}

    function openCourse() public {}
    // PROXY

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
