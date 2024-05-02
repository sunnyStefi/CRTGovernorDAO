# Certificate Generator and CertificantsDAO v0.2

This is a project that simulates a real world Certificate Generation Institution.
Each student can add one or more courses to their own Student Path.
A Certificate is granted for the student only when a certain number of courses are completed
in their due time. The Certificate can then be minted and transferred in the form of ERC1155 to the student who had earned it.

All the Certified students can participate in a DAO, the CertificatsDAO. More certificates a member has earned, more power in the DAO he can exert.

# Contracts

The project is made of 9 core contracts that interact and depend on each other. 

### 1. CourseFactory

This contract permits to create courses that have a verified true random id (obtained thorugh Chainlink VRF).
Each course has attributes that include IPFS uris to store more complex information.
Each course is of exclusive participation, having a finite number of available places. When all the available places will be taken, the course will change its state to CLOSE.

### 2. StudentPath

The user (Student) will have his own path, where all the courses he needs to follow are stored.
Each course is made of a set of lessons, which have their own content and their relative quiz.

A raw memory repetition pattern process has been implemented to let student retain information and reinforce their knowledge:

1. Short term review/quizzes (within 6 hours)
2. Daily review/quizzes (within 24 hours)
3. Weekly review/quizzes (within 1 week)
4. Monthly review/quizzes (within 1 month)

Only by respecting these appointments and successfully executing quizzers he will be able to earn his Certificate. No other exams or tests are needed. 
The StatusUpgrade function is punctually called obtained trough Chainlink Automation. (TODO)

Each lesson cmust follow one of the following states, (Lesson State Flow): EMPTY, SUBSCRIBED, SHORT_TERM_QUIZ_PASSED, DAILY_TERM_QUIZ_PASSED, WEEKLY_TERM_QUIZ_PASSED, COMPLETED

### 3. CertificateNFT

It's an NFT ERC1155 upgradeable contract that implements Access Control.
This is the asset that is minted and sent to the student that have completed his path.
It makes operations on Certificates and tracks them.
This contract implements methods that enables the NFT to be viewed on Opensea.

### 4. CRToken

ERC20 token (CERT) that can be minted only if the student has been certified.
The ratio between CRTokens minted and Certificates earned (ERC1155) must always be 1:1.
This token implements ERC20Votes and can be used to vote proposals inside a DAO, the CertificantsDAO.

### 5. CertificantsDAO

A DAO that is used by all Certified Student to vote on proposals.

The decision power is directly proportionate to the number of certificates that an user can have, enhancing the voting power for more expert people.

### 6. TimelockController

Implements TimelockController and is responsible for delaying calls of other contracts (CertificantsDAO, MakeStuff) in order to be accountable to its community.

### 7. MakeStuff

A dummy contract used by the CertificantsDAO to vote on.
It must belong to the TimelockController (via transferOwnership).

### 8. Interactions
Utils module that helps with all processes involved in creating a course (Contract CreateCourse) and building an unvaluated student path (Contract CreateStudentPath)

## Flow
General

<img src="img/flow_general.png" alt="DAO" width="600"/>

Course Factory

<img src="img/course_factory.png" alt="Factory" width="600"/>

Student Path

<img src="img/student_path.png" alt="StudentPath" width="600"/>

## Keywords
