// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../Proxy/DeYieldUpgradeableProxy.sol";
import "../libs/Errors.sol";
import "../interfaces/IDeYieldAddressesProvider.sol";
import "../libs/Constants.sol";

contract DeYieldAddressesProvider is AccessControl, IDeYieldAddressesProvider {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(bytes32 => address) public contracts;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getContract(string memory name) public view returns (address) {
        bytes32 _name = _convertStringToBytes32(name);
        address _contract = contracts[_name];
        if (_contract == address(0)) {
            revert Errors.ContractNotRegistered(name);
        }
        return _contract;
    }

    function setContractProxy(
        string memory name,
        address _implementation,
        bytes memory _data
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 _name = _convertStringToBytes32(name);

        if (contracts[_name] == address(0)) {
            DeYieldUpgradeableProxy contractInstance = new DeYieldUpgradeableProxy();
            contracts[_name] = address(contractInstance);
            emit ContractProxyCreated(name, contracts[_name], _implementation);
        }
        if (_data.length == 0) {
            ITransparentUpgradeableProxy(contracts[_name]).upgradeTo(
                _implementation
            );
        } else {
            ITransparentUpgradeableProxy(contracts[_name]).upgradeToAndCall(
                _implementation,
                _data
            );
        }
        emit ContractProxyUpdated(name, contracts[_name], _implementation);
    }

    function setContract(
        string memory _name,
        address _contract
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 name = _convertStringToBytes32(_name);
        address contract_ = contracts[name];
        if (contract_ != address(0)) {
            (bool success, bytes memory data) = contract_.call(
                abi.encodeWithSignature("admin()")
            );
            address admin = abi.decode(data, (address));
            if (success && admin == address(this)) {
                revert Errors.ContractAdminChangeNotAllowed(_name);
            }
        }
        contracts[name] = _contract;
        emit ContractUpdated(_name, _contract);
    }

    function getImplementation(
        string memory name
    ) public view returns (address) {
        bytes32 _name = _convertStringToBytes32(name);
        address _contract = contracts[_name];
        if (_contract == address(0)) {
            revert Errors.ContractNotRegistered(name);
        }
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("implementation()")) == 0x5c60da1b
        (bool success, bytes memory returndata) = _contract.staticcall(
            hex"5c60da1b"
        );
        require(success);
        return abi.decode(returndata, (address));
    }

    function _convertBytes32ToString(
        bytes32 _bytes32
    ) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function _convertStringToBytes32(
        string memory _string
    ) internal pure returns (bytes32) {
        if (bytes(_string).length == 0 || bytes(_string).length > 32) {
            revert Errors.InvalidContractName(_string);
        }
        bytes32 _bytes32;
        assembly {
            _bytes32 := mload(add(_string, 32))
        }
        return _bytes32;
    }

    function changeProxyAdmin(
        string memory name,
        address newAdmin
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        address _contract = getContract(name);
        ITransparentUpgradeableProxy _proxy = ITransparentUpgradeableProxy(
            _contract
        );
        _proxy.changeAdmin(newAdmin);
    }

    function getXUSD() public view override returns (address) {
        return getContract(Constants.XUSD);
    }

    function getVault() public view override returns (address) {
        return getContract(Constants.DEYIELD_VAULT);
    }

    function getOracle() public view override returns (address) {
        return getContract(Constants.ORACLE);
    }

    function getYEET() public view override returns (address) {
        return getContract(Constants.YEET);
    }

    function getFoundation() public view override returns (address) {
        return getContract(Constants.FOUNDATION);
    }
}
