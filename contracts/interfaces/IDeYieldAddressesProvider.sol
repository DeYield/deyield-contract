// SPDX: License-Identifier: MIT

interface IDeYieldAddressesProvider {
    event ContractProxyCreated(
        string name,
        address proxy,
        address implementation
    );
    event ContractProxyUpdated(
        string name,
        address proxy,
        address implementation
    );
    event ContractUpdated(string _name, address _contract);

    function getContract(string memory name) external view returns (address);
    function setContractProxy(
        string memory name,
        address _implementation,
        bytes memory _data
    ) external;

    function setContract(string memory _name, address _contract) external;

    function getImplementation(
        string memory name
    ) external view returns (address);

    function changeProxyAdmin(string memory name, address newAdmin) external;

    function getXUSD() external view returns (address);

    function getVault() external view returns (address);

    function getOracle() external view returns (address);

    function getYEET() external view returns (address);

    function getFoundation() external view returns (address);
}
