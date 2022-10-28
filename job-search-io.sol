//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract JobSearchIo {
    enum SERVICE_STATUS {
        STARTED,
        CANCELED,
        FINISHED,
        PAYED
    }
    struct Service {
        string id;
        address owner;
        address worker;
        uint256 value;
        SERVICE_STATUS status;
        bool worker_validation;
        bool owner_validation;
        uint evaluation;
        bool exists;
    }

    address admin;
    uint256 tax;

    mapping(address => uint256) balances;
    mapping(address => uint) servicesFinisheds;
    mapping(string => Service) services;

    constructor(uint initialTax) {
        admin = msg.sender;
        tax = initialTax;
    }

    event Received(address, uint);

    event Transfer(address indexed, address, uint256);

    function createService(
        string memory _id,
        address _owner,
        uint256 _value,
        address _worker
    ) external serviceValidation(_id, _owner, _value) {
        services[_id] = Service(
            _id,
            _owner,
            _worker,
            _value,
            SERVICE_STATUS.STARTED,
            false,
            false,
            0,
            true
        );
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    receive() external payable {
        this.deposit();
    }

    function myBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function balanceOf(address _owner)
        external
        view
        onlyOwnerAndAdmin(_owner)
        returns (uint256)
    {
        return balances[_owner];
    }

    function getService(string memory _id)
        external
        view
        serviceExists(_id)
        returns (Service memory)
    {
        return services[_id];
    }

    function transferTo(address _to, uint256 _amount) internal {
        require(
            address(this).balance >= _amount,
            "Balance lower than required in the transaction"
        );
        payable(_to).transfer(_amount);
        emit Transfer(msg.sender, _to, _amount);
    }

    function withDrawTransferTo(address _to, uint256 _amount)
        external
        onlyAdmin
    {
        require(
            address(this).balance >= _amount,
            "Balance lower than required in the transaction"
        );
        require(
            balances[msg.sender] >= _amount,
            "Balance less than the value of the transfer"
        );

        transferTo(_to, _amount);
    }

    function clientFinished(string memory _id, uint evaluation)
        external
        serviceExists(_id)
    {
        require(msg.sender == services[_id].owner, "Access denied");
        require(evaluation >= 0 && evaluation <= 5, "Access denied");

        services[_id].owner_validation = true;
        services[_id].evaluation = evaluation;

        finishService(_id);
    }

    function workerFinished(string memory _id) external serviceExists(_id) {
        require(msg.sender == services[_id].worker, "Access denied");

        services[_id].worker_validation = true;

        finishService(_id);
    }

    function finishService(string memory _id) internal {
        if (services[_id].worker_validation && services[_id].owner_validation) {
            servicesFinisheds[services[_id].owner] += 1;
            servicesFinisheds[services[_id].worker] += 1;

            services[_id].status = SERVICE_STATUS.FINISHED;
            payService(_id);
        }
    }

    function payService(string memory _id) internal {
        require(
            services[_id].status == SERVICE_STATUS.FINISHED,
            "It is not possible to make the payment in the current status of the service"
        );
        uint workerPayment;
        uint platformTaxPayment;
        uint serviceValue = services[_id].value;

        platformTaxPayment = (tax * serviceValue) / 100;

        balances[services[_id].owner] -= serviceValue;

        workerPayment = serviceValue - platformTaxPayment;
        balances[services[_id].worker] += workerPayment;

        // transferTo(services[_id].worker, workerPayment);
        balances[admin] += platformTaxPayment;
        services[_id].status == SERVICE_STATUS.PAYED;

        payGamification(_id);
    }

    function payGamification(string memory _id) internal {
        address worker = services[_id].worker;
        address owner = services[_id].owner;

        if (servicesFinisheds[worker] >= 3) {
            balances[worker] += 300000000000000000;
        }

        if (servicesFinisheds[owner] >= 3) {
            balances[owner] += 300000000000000000;
        }
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Nao eh o admin");
        _;
    }

    modifier onlyOwner(address _owner) {
        require(
            msg.sender == _owner,
            "Cannot create a service on behalf of a third party"
        );
        _;
    }

    modifier onlyOwnerAndAdmin(address _owner) {
        require(
            msg.sender == _owner || msg.sender == admin,
            "Cannot create a service on behalf of a third party"
        );
        _;
    }

    modifier serviceExists(string memory _id) {
        require(services[_id].exists, "Service is not registered");
        _;
    }

    modifier serviceValidation(
        string memory _id,
        address _owner,
        uint256 _value
    ) {
        require(!services[_id].exists, "Service already registered");
        require(msg.sender == admin, "Cannot create a service");
        require(
            balances[_owner] >= _value,
            "Balance less than the value of the service"
        );
        _;
    }
}
