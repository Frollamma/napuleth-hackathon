// Things you could improve:
// - add some "timeout" so that funds don't get "stuck" (for example in evaluateOrderRequest, if the buyer doesn't use createOrder only the agent commits to the order and there's no way to get back funds, for now...)
// - make fees for verifier changable
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Services.sol";

contract Orders is Ownable, Services {
    constructor(address initialOwner) Ownable(initialOwner) {
      verifier = initialOwner;
    }

    enum Status {
        Requested,
        Accepted,
        Rejected,
        Created,
        Delivered,
        Complete,
        Uncomplete,
        EvaluatedUncomplete,
        EvaluationDisputed,
        JustReviewed,
        ReviewDisputed,
        Reviewed
    }

    struct CompletionParams {
        uint id;
        string[] objTasks;
    }

    struct ReviewParams {
        uint id;
        string[] objQuestions;
        string[] subjQuestions;
        uint8[] objWeights;
        uint8[] subjWeights;
    }

    struct Review {
        uint id;
        uint reviewParamsId;
        uint8[] objAnswers;
        uint8[] subjAnswers;
    }
    
    struct Order {
        uint id;
        uint serviceId;
        address buyer;
        string inputURI;
        string outputURI;
        uint price;
        uint reviewDeposit;
        Status status;
        uint completionParamsId;
        uint reviewParamsId;
        uint reviewId;
    }

    uint public orderCounter;
    uint public completionParamsCounter;
    uint public reviewParamsCounter;
    uint public reviewsCounter;
    mapping(uint => Order) public idToOrder;
    mapping(uint => CompletionParams) public idToCompletionParams;
    mapping(uint => ReviewParams) public idToReviewParams;
    mapping(uint => Review) public idToReview;

    uint public reviewDepositAmount = 1 ether;
    uint public constant disputeOrderEvaluationFee = 1 ether;
    uint public constant disputeReviewFee = 1 ether;
    uint public constant platformFee = 1 ether;

    // address authorized to resolve disputes
    address public verifier;

    event VerifierChanged(address indexed previousVerifier, address indexed newVerifier);
    event ReviewDepositAmountChanged(uint indexed previousReviewDepositAmount, uint indexed newReviewDepositAmount);
    event OrderRequested(uint indexed orderId, address indexed buyer, uint indexed serviceId);
    event OrderRequestAccepted(uint indexed orderId);
    event OrderRequestRejected(uint indexed orderId);
    event OrderCreated(uint indexed orderId);
    event OrderDelivered(uint indexed orderId);
    event OrderEvaluated(uint indexed orderId, bool completed);
    event OrderEvaluationChecked(uint indexed orderId);
    event OrderEvaluationDisputeResolved(uint indexed orderId, bool completed);
    event OrderReviewed(uint indexed orderId, uint8 score);
    event ReviewDisputed(uint indexed orderId);
    event ReviewDisputeResolved(uint indexed orderId, bool buyerWins);

    modifier onlyBuyer(uint orderId) {
        require(idToOrder[orderId].buyer == msg.sender, "Not buyer");
        _;
    }
    modifier onlyOrderAgentOwner(uint orderId) {
        require(idToAgent[idToService[idToOrder[orderId].serviceId].agentId].owner == msg.sender, "Not agent");
        _;
    }
    modifier onlyVerifier() {
        require(msg.sender == verifier, "Not verifier");
        _;
    }


    function calculateWeightedScore(ReviewParams storage params, Review memory review) internal view returns (uint8) {
        uint sumWeights;
        uint sumScores;

        for (uint i = 0; i < params.objWeights.length; i++) {
            sumWeights += params.objWeights[i];
            sumScores += params.objWeights[i] * review.objAnswers[i];
        }

        for (uint i = 0; i < params.subjWeights.length; i++) {
            sumWeights += params.subjWeights[i];
            sumScores += params.subjWeights[i] * review.subjAnswers[i];
        }

        // Avoid division by zero
        if (sumWeights == 0) {
            return 0;
        }

        return uint8(sumScores / sumWeights);
    }

    /// @notice Allows the contract owner to designate a new verifier
    /// @param newVerifier The address of the new verifier
    function setVerifier(address newVerifier) external onlyOwner {
        require(newVerifier != address(0), "Invalid address");
        address old = verifier;
        verifier = newVerifier;
        emit VerifierChanged(old, newVerifier);
    }

    /// @notice Allows the contract owner to choose a new review deposit
    /// @param newReviewDepositAmount The new amount to deposit and get back when the buyer makes a review
    function setReviewDeposit(uint newReviewDepositAmount) external onlyOwner {
        uint old = reviewDepositAmount;
        reviewDepositAmount = newReviewDepositAmount;
        emit ReviewDepositAmountChanged(old, newReviewDepositAmount);
    }

    function requestOrder(
        uint serviceId,
        string[] calldata objTasks,
        string[] calldata objQuestions,
        string[] calldata subjQuestions,
        uint8[] calldata objWeights,
        uint8[] calldata subjWeights
    ) external {
        Service storage service = idToService[serviceId];
        require(service.price > 0, "Service not found");
        require(objQuestions.length == objWeights.length, "Same length please");
        require(subjQuestions.length == subjWeights.length, "Same length please");

        uint orderId = orderCounter;


        CompletionParams memory completionParams = CompletionParams({
            id:           completionParamsCounter,
            objTasks: objTasks
        });
        idToCompletionParams[completionParamsCounter] = completionParams;
        completionParamsCounter++;

        ReviewParams memory reviewParams = ReviewParams({
            id:           reviewParamsCounter,
            objQuestions: objQuestions,
            subjQuestions: subjQuestions,
            objWeights:   objWeights,
            subjWeights:  subjWeights
        });
        idToReviewParams[reviewParamsCounter] = reviewParams;
        reviewParamsCounter++;

        orderCounter++;
        idToOrder[orderId] = Order({
            id: orderId,
            serviceId: serviceId,
            buyer: msg.sender,
            inputURI: "",
            outputURI: "",
            price: service.price,
            reviewDeposit: reviewDepositAmount,
            status: Status.Requested,
            completionParamsId: completionParamsCounter,
            reviewParamsId: reviewParamsCounter,
            reviewId: 0
        });

        emit OrderRequested(orderId, msg.sender, serviceId);
    }

    function evaluateOrderRequest(uint orderId, bool accept) external payable onlyOrderAgentOwner(orderId) {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.Requested, "Wrong status");

        if (!accept) {
            order.status = Status.Rejected;
            payable(order.buyer).transfer(order.reviewDeposit);
            emit OrderRequestRejected(orderId);
            return;
        }

        require(msg.value == disputeOrderEvaluationFee + disputeReviewFee, "You must commit to cover dispute expenses in case of (your) bad behavior");
        order.status = Status.Accepted;
        emit OrderRequestAccepted(orderId);
    }

    function createOrder(uint orderId, string calldata inputURI) external payable onlyBuyer(orderId) {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.Accepted, "Not accepted");
        require(msg.value == order.price + order.reviewDeposit + disputeOrderEvaluationFee + disputeReviewFee, "Incorrect payment");
        order.inputURI = inputURI;
        order.status = Status.Created;
        emit OrderCreated(orderId);
    }

    function deliverOrder(uint orderId, string calldata outputURI) external onlyOrderAgentOwner(orderId) {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.Created, "Wrong status");
        order.outputURI = outputURI;
        order.status = Status.Delivered;
        emit OrderDelivered(orderId);
    }

    function evaluateOrder(uint orderId, bool completed) external onlyBuyer(orderId) {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.Delivered, "Wrong status");
        order.status = completed ? Status.Complete : Status.EvaluatedUncomplete;
        emit OrderEvaluated(orderId, completed);
        if (completed) {
            payable(idToAgent[idToService[order.serviceId].agentId].owner).transfer(order.price + disputeOrderEvaluationFee - platformFee);
            payable(order.buyer).transfer(disputeOrderEvaluationFee);
        }
    }

    function checkOrderEvaluation(uint orderId, bool dispute) external onlyOrderAgentOwner(orderId) {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.EvaluatedUncomplete, "Cannot confirm or dispute with this state");
        if (dispute) {
          order.status = Status.EvaluationDisputed;
        } else {
          order.status = Status.Uncomplete;
          // No one lied but the order is not complete
          payable(order.buyer).transfer(order.price + disputeOrderEvaluationFee + disputeReviewFee + order.reviewDeposit);
        }
        emit OrderEvaluationChecked(orderId);
    }

    function solveOrderEvaluationDispute(uint orderId, bool completed) external onlyVerifier {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.EvaluationDisputed, "No dispute");
        order.status = completed ? Status.Complete : Status.Uncomplete;
        emit OrderEvaluationDisputeResolved(orderId, completed);
        if (completed) {
            // The buyer lied
            payable(idToAgent[idToService[order.serviceId].agentId].owner).transfer(order.price + disputeOrderEvaluationFee);
        } else {
            // The agent lied
            payable(order.buyer).transfer(order.price + disputeOrderEvaluationFee);
        }
    }

    function reviewOrder(uint orderId, uint8[] calldata objAnswers, uint8[] calldata subjAnswers) external onlyBuyer(orderId) {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.Complete, "Cannot evaluate this order");
        require(objAnswers.length == idToReviewParams[order.reviewParamsId].objWeights.length, "Same length please");
        require(subjAnswers.length == idToReviewParams[order.reviewParamsId].subjWeights.length, "Same length please");
        
        idToReview[reviewsCounter] = Review({
          id: reviewsCounter,
          reviewParamsId: order.reviewParamsId,
          objAnswers: objAnswers,
          subjAnswers: subjAnswers
        });
        order.reviewId = reviewsCounter;
        reviewsCounter++;
        order.status = Status.JustReviewed;
        uint8 reviewScore = calculateWeightedScore(idToReviewParams[order.reviewParamsId], idToReview[order.reviewId]);
        emit OrderReviewed(orderId, reviewScore );
    }

    function checkReview(uint orderId, bool dispute) external onlyOrderAgentOwner(orderId) {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.JustReviewed, "Cannot chack this order review");

        if (dispute) {
          order.status = Status.ReviewDisputed;
        } else {
          // Everybody is happy with the review
          uint reviewScore = calculateWeightedScore(idToReviewParams[order.reviewParamsId], idToReview[order.reviewId]);
          Service storage service = idToService[order.serviceId];
          service.totReviews++;
          service.reputation += reviewScore;
          order.status = Status.Reviewed;

          payable(order.buyer).transfer(order.reviewDeposit + disputeReviewFee);
          payable(idToAgent[idToService[order.serviceId].agentId].owner).transfer(disputeReviewFee);
        }
        emit ReviewDisputed(orderId);
    }

    function solveReviewDispute(uint orderId, bool buyerWins, Review memory review) external onlyVerifier {
        Order storage order = idToOrder[orderId];
        require(order.status == Status.ReviewDisputed, "No dispute");
        require(review.objAnswers.length == idToReviewParams[order.reviewParamsId].objWeights.length, "Same length please");
        require(review.subjAnswers.length == idToReviewParams[order.reviewParamsId].subjWeights.length, "Same length please");

        idToReview[reviewsCounter] = review;
        reviewsCounter++;

        uint reviewScore = calculateWeightedScore(idToReviewParams[order.reviewParamsId], idToReview[order.reviewId]);
        Service storage service = idToService[order.serviceId];
        service.totReviews++;
        service.reputation += reviewScore;
        order.status = Status.Reviewed;
        
        if (buyerWins) {
          // agent lied
          payable(order.buyer).transfer(order.reviewDeposit + disputeReviewFee);
        } else {
          // buyer lied
          payable(idToAgent[idToService[order.serviceId].agentId].owner).transfer(disputeReviewFee);
        }

        emit ReviewDisputeResolved(orderId, buyerWins);
    }
}
