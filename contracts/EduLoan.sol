// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title EduLoan - Decentralized Student Loan System
/// @author Rani Setiawati
/// @notice Sistem pinjaman pendidikan terdesentralisasi di Mantle Network
contract EduLoan {

    // ========================
    // Enum & Struct
    // ========================
    enum LoanStatus { Pending, Approved, Active, Repaid, Defaulted }

    struct Loan {
        uint256 loanId;
        address borrower;
        uint256 principalAmount;
        uint256 interestRate;
        uint256 totalAmount;
        uint256 amountRepaid;
        uint256 applicationTime;
        uint256 approvalTime;
        uint256 deadline;
        LoanStatus status;
        string purpose;
    }

    // ========================
    // State Variables
    // ========================
    address public admin;
    uint256 public loanCounter;
    uint256 public constant INTEREST_RATE = 500; // 5% basis points
    uint256 public constant LOAN_DURATION = 365 days;
    uint256 public constant MIN_LOAN = 0.01 ether;
    uint256 public constant MAX_LOAN = 10 ether;

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;

    // ========================
    // Events
    // ========================
    event LoanApplied(uint256 indexed loanId, address indexed borrower, uint256 amount, string purpose);
    event LoanApproved(uint256 indexed loanId, address indexed borrower, uint256 totalAmount);
    event LoanRejected(uint256 indexed loanId, address indexed borrower, string reason);
    event LoanDisbursed(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event PaymentMade(uint256 indexed loanId, address indexed borrower, uint256 amount, uint256 remaining);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower);
    event LoanDefaulted(uint256 indexed loanId, address indexed borrower);

    // ========================
    // Modifiers
    // ========================
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }

    modifier loanExists(uint256 _loanId) {
        require(_loanId > 0 && _loanId <= loanCounter, "Loan does not exist");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(loans[_loanId].borrower == msg.sender, "Only borrower can call this");
        _;
    }

    modifier inStatus(uint256 _loanId, LoanStatus _status) {
        require(loans[_loanId].status == _status, "Loan is not in required status");
        _;
    }

    // ========================
    // Constructor
    // ========================
    constructor() {
        admin = msg.sender;
        loanCounter = 0;
    }

    // ========================
    // Main Functions
    // ========================
    function applyLoan(uint256 _amount, string memory _purpose) public {
        require(_amount >= MIN_LOAN && _amount <= MAX_LOAN, "Amount out of range");
        loanCounter++;
        uint256 total = _amount + calculateInterest(_amount);

        loans[loanCounter] = Loan({
            loanId: loanCounter,
            borrower: msg.sender,
            principalAmount: _amount,
            interestRate: INTEREST_RATE,
            totalAmount: total,
            amountRepaid: 0,
            applicationTime: block.timestamp,
            approvalTime: 0,
            deadline: 0,
            status: LoanStatus.Pending,
            purpose: _purpose
        });

        borrowerLoans[msg.sender].push(loanCounter);
        emit LoanApplied(loanCounter, msg.sender, _amount, _purpose);
    }

    function approveLoan(uint256 _loanId) public onlyAdmin loanExists(_loanId) inStatus(_loanId, LoanStatus.Pending) {
        loans[_loanId].status = LoanStatus.Approved;
        loans[_loanId].approvalTime = block.timestamp;
        emit LoanApproved(_loanId, loans[_loanId].borrower, loans[_loanId].totalAmount);
    }

    function rejectLoan(uint256 _loanId, string memory _reason) public onlyAdmin loanExists(_loanId) inStatus(_loanId, LoanStatus.Pending) {
        loans[_loanId].status = LoanStatus.Defaulted;
        emit LoanRejected(_loanId, loans[_loanId].borrower, _reason);
    }

    function disburseLoan(uint256 _loanId) public onlyAdmin loanExists(_loanId) inStatus(_loanId, LoanStatus.Approved) {
        require(address(this).balance >= loans[_loanId].principalAmount, "Contract balance too low");
        loans[_loanId].status = LoanStatus.Active;
        loans[_loanId].deadline = block.timestamp + LOAN_DURATION;
        payable(loans[_loanId].borrower).transfer(loans[_loanId].principalAmount);
        emit LoanDisbursed(_loanId, loans[_loanId].borrower, loans[_loanId].principalAmount);
    }

    function makePayment(uint256 _loanId) public payable onlyBorrower(_loanId) inStatus(_loanId, LoanStatus.Active) {
        require(msg.value > 0, "Payment must be > 0");
        loans[_loanId].amountRepaid += msg.value;

        if (loans[_loanId].amountRepaid >= loans[_loanId].totalAmount) {
            loans[_loanId].status = LoanStatus.Repaid;
            emit LoanRepaid(_loanId, msg.sender);
        }

        emit PaymentMade(_loanId, msg.sender, msg.value, getRemainingAmount(_loanId));
    }

    function checkDefault(uint256 _loanId) public loanExists(_loanId) {
        Loan storage loan = loans[_loanId];
        if (loan.status == LoanStatus.Active && block.timestamp > loan.deadline && loan.amountRepaid < loan.totalAmount) {
            loan.status = LoanStatus.Defaulted;
            emit LoanDefaulted(_loanId, loan.borrower);
        }
    }

    // ========================
    // View Functions
    // ========================
    function getLoanDetails(uint256 _loanId) public view loanExists(_loanId) returns (Loan memory) {
        return loans[_loanId];
    }

    function getMyLoans() public view returns (uint256[] memory) {
        return borrowerLoans[msg.sender];
    }

    function calculateInterest(uint256 _principal) public pure returns (uint256) {
        return (_principal * INTEREST_RATE) / 10000;
    }

    function getRemainingAmount(uint256 _loanId) public view loanExists(_loanId) returns (uint256) {
        Loan storage loan = loans[_loanId];
        if (loan.amountRepaid >= loan.totalAmount) return 0;
        return loan.totalAmount - loan.amountRepaid;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // ========================
    // Admin Functions
    // ========================
    function depositFunds() public payable onlyAdmin {}
    
    function withdrawFunds(uint256 _amount) public onlyAdmin {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(admin).transfer(_amount);
    }
}
