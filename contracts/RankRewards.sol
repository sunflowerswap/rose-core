pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

contract WhitelistAdminRole {
    using Roles for Roles.Role;

    event WhitelistAdminAdded(address indexed account);
    event WhitelistAdminRemoved(address indexed account);

    Roles.Role private _whitelistAdmins;

    constructor () internal {
        _addWhitelistAdmin(msg.sender);
    }

    modifier onlyWhitelistAdmin() {
        require(isWhitelistAdmin(msg.sender), "WhitelistAdminRole: caller does not have the WhitelistAdmin role");
        _;
    }

    function isWhitelistAdmin(address account) public view returns (bool) {
        return _whitelistAdmins.has(account);
    }

    function addWhitelistAdmin(address account) public onlyWhitelistAdmin {
        _addWhitelistAdmin(account);
    }

    function renounceWhitelistAdmin() public {
        _removeWhitelistAdmin(msg.sender);
    }

    function _addWhitelistAdmin(address account) internal {
        _whitelistAdmins.add(account);
        emit WhitelistAdminAdded(account);
    }

    function _removeWhitelistAdmin(address account) internal {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }
}

contract RankRewards is WhitelistAdminRole {

    IERC20 public roseToken;
    mapping(uint => mapping (address => uint)) public users;
    mapping(uint => uint) public totalRoseRewards;

    constructor(IERC20 _roseToken) public {
        roseToken = _roseToken;
    }

    function roseBalance() public view returns(uint) {
        return roseToken.balanceOf(address(this));
    }

    function setRoseToken(IERC20 _roseToken) public onlyWhitelistAdmin {
        roseToken = _roseToken;
    }

    function RankRewardsForPCC(address[] memory _to, uint[] memory _amount) public {
        tokenRewards(roseToken, 1, _to, _amount);
    }

    function RankRewardsForSFR(address[] memory _to, uint[] memory _amount) public {
        tokenRewards(roseToken, 2, _to, _amount);
    }

    function tokenRewards(IERC20 token, uint rewardType, address[] memory _to, uint[] memory _amount) public onlyWhitelistAdmin {
        require(_to.length == _amount.length, "length error");
        uint rewards = 0;
        for(uint i =0; i < _to.length; i++){
            token.transfer(_to[i], _amount[i]);
            users[rewardType][_to[i]] += _amount[i];
            rewards += _amount[i];
        }
        totalRoseRewards[rewardType] += rewards;
    }

    function tokenRewardsSimple(IERC20 token, address[] memory _to, uint[] memory _amount) public onlyWhitelistAdmin {
        require(_to.length == _amount.length, "length error");
        for(uint i =0; i < _to.length; i++){
            token.transfer(_to[i], _amount[i]);
        }
    }

}
