// SPDX: License-Identifier: MIT

library Errors {
    error InvalidContract(address contract_);
    error ContractNotRegistered(string name);
    error InvalidContractName(string name);
    error InvalidInputLength();
    error AssetNotRegistered(address token);
    error ContractAdminChangeNotAllowed(string name);
}
