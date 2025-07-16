pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Services.sol";

contract Orders is Ownable, Services {
    constructor(address initialOwner) Ownable(initialOwner) {}

    enum Status {
        Requested,
        Accepted,
        Created,
        Delivered,
        Evaluated,
        EvalDisputed,
        EvalResolved,
        Reviewed,
        ReviewDisputed,
        ReviewResolved
    }

    struct ReviewParams {
        uint8[] objAnswers;
        uint8[] subjAnswers;
        uint8[] objWeights;
        uint8[] subjWeights;
    }

    struct Order {
        uint id;
        uint serviceId;
        address buyer;
        address agent;
        string inputURI;
        string outputURI;
        uint price;
        uint reviewDeposit;
        Status status;
        ReviewParams params;
        bool evaluation;
        bool reviewVerdict;
    }

    uint public orderCounter;
    mapping(uint => Order) public idToOrder;

    // fixed amounts for deposits and disputes
    uint public constant reviewDepositAmount = 1 ether;
    uint public constant disputeOrderEvaluationFee = 0.01 ether;
    uint public constant disputeReviewFee = 0.01 ether;

    event OrderRequested(uint indexed orderId, address indexed buyer, uint indexed serviceId);
    event OrderRequestAccepted(uint indexed orderId);
    event OrderRequestRejected(uint indexed orderId);
    event OrderCreated(uint indexed orderId);
    event OrderDelivered(uint indexed orderId);
    event OrderEvaluated(uint indexed orderId, bool completed);
    event OrderEvaluationDisputed(uint indexed orderId);
    event EvaluationDisputeResolved(uint indexed orderId, bool completed);
    event OrderReviewed(uint indexed orderId, uint8 score);
    event ReviewDisputed(uint indexed orderId);
    event ReviewDisputeResolved(uint indexed orderId, bool buyerWins);
    event ReviewDepositRedeemed(uint indexed orderId);

    modifier onlyBuyer(uint orderId) {
        require(idToOrder[orderId].buyer == msg.sender, "Not buyer");
        _;
    }
    modifier onlyAgentOf(uint orderId) {
        require(idToOrder[orderId].agent == msg.sender, "Not agent");
        _;
    }
    modifier onlyVerifier() {
        require(msg.sender == owner(), "Not verifier");
        _;
    }

    function requestOrder(
        uint serviceId,
        uint8[] calldata objAnswers,
        uint8[] calldata subjAnswers,
        uint8[] calldata objWeights,
        uint8[] calldata subjWeights
    ) external payable {
        Service storage service = idToService[serviceId];
        require(service.price > 0, "Service not found");
        require(msg.value == reviewDepositAmount, "Incorrect review deposit");

        uint orderId = orderCounter++;
        idToOrder[orderId] = Order({
            id: orderId,
            serviceId: serviceId,
            buyer: msg.sender,
            agent: idToAgent[service.agentId].owner,
            inputURI: "",
            outputURI: "",
            price: service.price,
            reviewDeposit: msg.value,
            status: Status.Requested,
            params: ReviewParams({
                objAnswers: objAnswers,
                subjAnswers: subjAnswers,
                objWeights: objWeights,
                subjWeights: subjWeights
            }),
            evaluation: false,
            reviewVerdict: false
        });
        emit OrderRequested(orderId, msg.sender, serviceId);
    }

    function evaluateOrderRequest(uint orderId, bool accept) external onlyAgentOf(orderId) {
        Order storage o = idToOrder[orderId];
        require(o.status == Status.Requested, "Wrong status");
        if (!accept) {
            o.status = Status.ReviewResolved;
            payable(o.buyer).transfer(o.reviewDeposit);
            emit OrderRequestRejected(orderId);
            return;
        }
        o.status = Status.Accepted;
        emit OrderRequestAccepted(orderId);
    }

    function createOrder(uint orderId, string calldata inputURI) external payable onlyBuyer(orderId) {
        Order storage o = idToOrder[orderId];
        require(o.status == Status.Accepted, "Not accepted");
        require(msg.value == o.price, "Incorrect payment");
        o.inputURI = inputURI;
        o.status = Status.Created;
        emit OrderCreated(orderId);
    }

    function deliverOrder(uint orderId, string calldata outputURI) external onlyAgentOf(orderId) {
        Order storage o = idToOrder[orderId];
        require(o.status == Status.Created, "Wrong status");
        o.outputURI = outputURI;
        o.status = Status.Delivered;
        emit OrderDelivered(orderId);
    }

    function evaluateOrder(uint orderId, bool completed) external onlyBuyer(orderId) {
        Order storage o = idToOrder[orderId];
        require(o.status == Status.Delivered, "Wrong status");
        o.evaluation = completed;
        o.status = completed ? Status.Evaluated : Status.EvalDisputed;
        emit OrderEvaluated(orderId, completed);
        if (completed) {
            payable(o.agent).transfer(o.price);
        }
    }

    function disputeOrderEvaluation(uint orderId) external payable onlyAgentOf(orderId) {
        require(msg.value == disputeOrderEvaluationFee, "Incorrect dispute fee");
        Order storage o = idToOrder[orderId];
        require(o.status == Status.EvalDisputed, "Cannot dispute");
        emit OrderEvaluationDisputed(orderId);
    }

    function solveOrderEvaluationDispute(uint orderId, bool completed) external onlyVerifier {
        Order storage o = idToOrder[orderId];
        require(o.status == Status.EvalDisputed, "No dispute");
        o.evaluation = completed;
        o.status = Status.EvalResolved;
        emit EvaluationDisputeResolved(orderId, completed);
        if (completed) {
            payable(o.agent).transfer(o.price);
        } else {
            payable(o.buyer).transfer(o.price);
        }
    }

    function reviewOrder(uint orderId) external onlyBuyer(orderId) {
        Order storage o = idToOrder[orderId];
        require(o.status == Status.EvalResolved || o.status == Status.Evaluated, "Not ready");
        uint sumW;
        uint sumS;
        for (uint i = 0; i < o.params.objWeights.length; i++) {
            sumW += o.params.objWeights[i];
            sumS += o.params.objWeights[i] * o.params.objAnswers[i];
        }
        for (uint i = 0; i < o.params.subjWeights.length; i++) {
            sumW += o.params.subjWeights[i];
            sumS += o.params.subjWeights[i] * o.params.subjAnswers[i];
        }
        uint8 score = uint8(sumS / sumW);
        Service storage service = idToService[o.serviceId];
        service.totReviews++;
        service.reputation += score;
        o.status = Status.Reviewed;
        emit OrderReviewed(orderId, score);
    }

    function disputeReview(uint orderId) external payable onlyAgentOf(orderId) {
        require(msg.value == disputeReviewFee, "Incorrect dispute fee");
        Order storage o = idToOrder[orderId];
        require(o.status == Status.Reviewed, "Cannot dispute");
        o.status = Status.ReviewDisputed;
        emit ReviewDisputed(orderId);
    }

    function solveReviewDispute(uint orderId, bool buyerWins) external onlyVerifier {
        Order storage o = idToOrder[orderId];
        require(o.status == Status.ReviewDisputed, "No dispute");
        o.reviewVerdict = buyerWins;
        o.status = Status.ReviewResolved;
        emit ReviewDisputeResolved(orderId, buyerWins);
    }

    function redeemReviewDeposit(uint orderId) external onlyBuyer(orderId) {
        Order storage o = idToOrder[orderId];
        require(
            o.status == Status.ReviewResolved || o.status == Status.Reviewed,
            "Not redeemable"
        );
        bool refundable = (o.status == Status.ReviewResolved && o.reviewVerdict) || o.status == Status.Reviewed;
        require(refundable, "Deposit lost");
        uint amount = o.reviewDeposit;
        o.reviewDeposit = 0;
        payable(o.buyer).transfer(amount);
        emit ReviewDepositRedeemed(orderId);
    }
}
