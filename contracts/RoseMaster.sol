pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RoseToken.sol";
import "./IUniswapV2Pair.sol";

// RoseMaster is the master of Rose. He can make Rose and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ROSE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract RoseMaster is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ROSEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRosePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRosePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo1 {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. ROSEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that ROSEs distribution occurs.
        uint256 accRosePerShare; // Accumulated ROSEs per share, times 1e12. See below.
        // Lock LP, until the end of mining.
        uint256 totalAmount;
    }

    // Info of each pool.
    struct PoolInfo2 {
        uint256 allocPoint; // How many allocation points assigned to this pool. ROSEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that ROSEs distribution occurs.
        uint256 accRosePerShare; // Accumulated ROSEs per share, times 1e12. See below.
        uint256 lastUnlockedBlock; // Last block number that pool to renovate.
        // Lock LP, until the pool update.
        uint256 lockedAmount;
        uint256 freeAmount;
        uint256 maxLockAmount;
        uint256 unlockIntervalBlock;
        uint256 feeAmount;
        uint256 sharedFeeAmount;
    }

    // Info of each period.
    struct PeriodInfo {
        uint256 endBlock;
        uint256 blockReward;
    }

    // The ROSE TOKEN!
    RoseToken public rose;
    // Dev address.
    address public devaddr;
    // Rank address .
    address public rankAddr;
    // Autonomous communities address.
    address public communityAddr;
    // Sunflower address.
    address public sfr;
    // UnisawpV2Pair SFR-ROSE.
    IUniswapV2Pair public sfr2rose;

    // Info of each pool.
    PoolInfo1[] public poolInfo1;
    // Info of each pool.
    PoolInfo2[] public poolInfo2;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo1;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo2;
    // Total allocation points. Must be the sum of all allocation points in all pool1s.
    uint256 public allocPointPool1 = 0;
    // Total allocation points. Must be the sum of all allocation points in all pool2s.
    uint256 public allocPointPool2 = 0;
    // The block number when ROSE mining starts.
    uint256 public startBlock;
    // User address to referrer address.
    mapping(address => address) public referrers;
    mapping(address => address[]) referreds1;
    mapping(address => address[]) referreds2;

    // Mint period info.
    PeriodInfo[] public periodInfo;

    event Deposit1(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw1(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw1(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event Deposit2(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw2(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw2(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        RoseToken _rose,
        address _sfr,
        address _devaddr,
        address _topReferrer,
        uint256 _startBlock,
        uint256 _firstBlockReward,
        uint256 _supplyPeriod,
        uint256 _maxSupply
    ) public {
        rose = _rose;
        sfr = _sfr;
        devaddr = _devaddr;
        startBlock = _startBlock;

        // the block rewards and the block at the end of the period.
        uint256 _supplyPerPeriod = _maxSupply / _supplyPeriod;
        uint256 lastPeriodEndBlock = _startBlock;
        for (uint256 i = 0; i < _supplyPeriod; i++) {
            lastPeriodEndBlock = lastPeriodEndBlock.add(
                _supplyPerPeriod.div(_firstBlockReward) << i
            );
            periodInfo.push(
                PeriodInfo({
                    endBlock: lastPeriodEndBlock,
                    blockReward: _firstBlockReward >> i
                })
            );
        }

        referrers[_topReferrer] = _topReferrer;
    }

    function pool1Length() external view returns (uint256) {
        return poolInfo1.length;
    }

    function pool2Length() external view returns (uint256) {
        return poolInfo2.length;
    }

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        require(block.number < startBlock);
        startBlock = _startBlock;
    }

    function setSfr2rose(address _sfr2rose) external onlyOwner {
        sfr2rose = IUniswapV2Pair(_sfr2rose);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add1(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePool1s();
        }
        uint256 firstBlock = block.number > startBlock
            ? block.number
            : startBlock;
        allocPointPool1 = allocPointPool1.add(_allocPoint);
        poolInfo1.push(
            PoolInfo1({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: firstBlock,
                accRosePerShare: 0,
                totalAmount: 0
            })
        );
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add2(
        uint256 _allocPoint,
        bool _withUpdate,
        uint256 _maxLockAmount,
        uint256 _unlockIntervalBlock
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePool2s();
        }
        uint256 firstBlock = block.number > startBlock
            ? block.number
            : startBlock;
        allocPointPool2 = allocPointPool2.add(_allocPoint);
        poolInfo2.push(
            PoolInfo2({
                allocPoint: _allocPoint,
                lastRewardBlock: firstBlock,
                accRosePerShare: 0,
                lastUnlockedBlock: 0,
                lockedAmount: 0,
                freeAmount: 0,
                maxLockAmount: _maxLockAmount,
                unlockIntervalBlock: _unlockIntervalBlock,
                feeAmount: 0,
                sharedFeeAmount: 0
            })
        );
    }

    // Update the given pool's ROSE allocation point. Can only be called by the owner.
    function set1(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePool1s();
        }
        allocPointPool1 = allocPointPool1.sub(poolInfo1[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo1[_pid].allocPoint = _allocPoint;
    }

    // Update the given pool's ROSE allocation point. Can only be called by the owner.
    function set2(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePool2s();
        }
        allocPointPool2 = allocPointPool2.sub(poolInfo2[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo2[_pid].allocPoint = _allocPoint;
    }

    function setMaxLockAmount(uint256 _pid, uint256 _maxLockAmount)
        external
        onlyOwner
    {
        poolInfo2[_pid].maxLockAmount = _maxLockAmount;
    }

    function setUnlockIntervalBlock(uint256 _pid, uint256 _unlockIntervalBlock)
        external
        onlyOwner
    {
        poolInfo2[_pid].unlockIntervalBlock = _unlockIntervalBlock;
    }

    function getBlockRewardNow() public view returns (uint256) {
        return getBlockRewards(block.number, block.number + 1);
    }

    function getBlockRewards(uint256 from, uint256 to)
        public
        view
        returns (uint256 rewards)
    {
        if (from < startBlock) {
            from = startBlock;
        }
        if (from >= to) {
            return 0;
        }

        for (uint256 i = 0; i < periodInfo.length; i++) {
            if (periodInfo[i].endBlock >= to) {
                return to.sub(from).mul(periodInfo[i].blockReward).add(rewards);
            } else if (periodInfo[i].endBlock <= from) {
                continue;
            } else {
                rewards = rewards.add(
                    periodInfo[i].endBlock.sub(from).mul(
                        periodInfo[i].blockReward
                    )
                );
                from = periodInfo[i].endBlock;
            }
        }
    }

    // View function to see pending ROSEs on frontend.
    function pendingRose1(uint256 _pid, address _user)
        public
        view
        returns (uint256)
    {
        PoolInfo1 storage pool = poolInfo1[_pid];
        UserInfo storage user = userInfo1[_pid][_user];
        uint256 accRosePerShare = pool.accRosePerShare;
        uint256 lpSupply = pool.totalAmount;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blockRewards = getBlockRewards(
                pool.lastRewardBlock,
                block.number
            );
            // pool1 hold 70% rewards.
            blockRewards = blockRewards.mul(7).div(10);
            uint256 roseReward = blockRewards.mul(pool.allocPoint).div(
                allocPointPool1
            );
            accRosePerShare = accRosePerShare.add(
                roseReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accRosePerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see pending ROSEs on frontend.
    function pendingRose2(uint256 _pid, address _user)
        public
        view
        returns (uint256)
    {
        PoolInfo2 storage pool = poolInfo2[_pid];
        UserInfo storage user = userInfo2[_pid][_user];
        uint256 accRosePerShare = pool.accRosePerShare;
        uint256 lpSupply = pool.lockedAmount.add(pool.freeAmount);
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blockRewards = getBlockRewards(
                pool.lastRewardBlock,
                block.number
            );
            // pool2 hold 30% rewards.
            blockRewards = blockRewards.mul(3).div(10);
            uint256 roseReward = blockRewards.mul(pool.allocPoint).div(
                allocPointPool2
            );
            accRosePerShare = accRosePerShare.add(
                roseReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accRosePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePool1s() public {
        uint256 length = poolInfo1.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool1(pid);
        }
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePool2s() public {
        uint256 length = poolInfo2.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool2(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool1(uint256 _pid) public {
        PoolInfo1 storage pool = poolInfo1[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.totalAmount;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blockRewards = getBlockRewards(
            pool.lastRewardBlock,
            block.number
        );
        // pool1 hold 70% rewards.
        blockRewards = blockRewards.mul(7).div(10);
        uint256 roseReward = blockRewards.mul(pool.allocPoint).div(
            allocPointPool1
        );
        rose.mint(devaddr, roseReward.div(10));
        if (rankAddr != address(0)) {
            rose.mint(rankAddr, roseReward.mul(9).div(100));
        }
        if (communityAddr != address(0)) {
            rose.mint(communityAddr, roseReward.div(100));
        }
        rose.mint(address(this), roseReward);
        pool.accRosePerShare = pool.accRosePerShare.add(
            roseReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool2(uint256 _pid) public {
        PoolInfo2 storage pool = poolInfo2[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lockedAmount.add(pool.freeAmount);
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blockRewards = getBlockRewards(
            pool.lastRewardBlock,
            block.number
        );
        // pool2 hold 30% rewards
        blockRewards = blockRewards.mul(3).div(10);
        uint256 roseReward = blockRewards.mul(pool.allocPoint).div(
            allocPointPool2
        );
        rose.mint(devaddr, roseReward.div(10));
        if (rankAddr != address(0)) {
            rose.mint(rankAddr, roseReward.mul(9).div(100));
        }
        if (communityAddr != address(0)) {
            rose.mint(communityAddr, roseReward.div(100));
        }
        rose.mint(address(this), roseReward);
        pool.accRosePerShare = pool.accRosePerShare.add(
            roseReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to RoseMain for ROSE allocation.
    function deposit1(uint256 _pid, uint256 _amount) public {
        PoolInfo1 storage pool = poolInfo1[_pid];
        UserInfo storage user = userInfo1[_pid][msg.sender];
        updatePool1(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount
                .mul(pool.accRosePerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeRoseTransfer(msg.sender, pending);
                mintReferralReward(pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
            pool.totalAmount = pool.totalAmount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRosePerShare).div(1e12);
        emit Deposit1(msg.sender, _pid, _amount);
    }

    // Deposit LP tokens to RoseMaster for ROSE allocation.
    function deposit2(uint256 _pid, uint256 _amount) public {
        PoolInfo2 storage pool = poolInfo2[_pid];
        UserInfo storage user = userInfo2[_pid][msg.sender];
        updatePool2(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount
                .mul(pool.accRosePerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeRoseTransfer(msg.sender, pending);
                mintReferralReward(pending);
            }
        }
        if (_amount > 0) {
            _safeTransferFrom(sfr, address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.lockedAmount = pool.lockedAmount.add(_amount);
        }
        updateLockedAmount(pool);
        user.rewardDebt = user.amount.mul(pool.accRosePerShare).div(1e12);
        emit Deposit2(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from RoseMain.
    function withdraw1(uint256 _pid, uint256 _amount) public {
        PoolInfo1 storage pool = poolInfo1[_pid];
        UserInfo storage user = userInfo1[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool1(_pid);
        uint256 pending = user.amount.mul(pool.accRosePerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeRoseTransfer(msg.sender, pending);
            mintReferralReward(pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.totalAmount = pool.totalAmount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRosePerShare).div(1e12);
        emit Withdraw1(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from RoseMaster.
    function withdraw2(uint256 _pid, uint256 _amount) public {
        UserInfo storage user = userInfo2[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        PoolInfo2 storage pool = poolInfo2[_pid];
        updateLockedAmount(pool);
        require(
            _amount <= pool.freeAmount,
            "withdraw: insufficient free balance in pool"
        );
        updatePool2(_pid);
        uint256 pending = user.amount.mul(pool.accRosePerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeRoseTransfer(msg.sender, pending);
            mintReferralReward(pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.freeAmount = pool.freeAmount.sub(_amount);
            // reduce the fee of 0.3%
            uint256 fee = _amount.mul(3).div(1000);
            pool.feeAmount = pool.feeAmount.add(fee);
            _safeTransfer(sfr, address(msg.sender), _amount.sub(fee));
        }
        user.rewardDebt = user.amount.mul(pool.accRosePerShare).div(1e12);
        emit Withdraw2(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw1(uint256 _pid) public {
        PoolInfo1 storage pool = poolInfo1[_pid];
        UserInfo storage user = userInfo1[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw1(msg.sender, _pid, amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw2(uint256 _pid) public {
        PoolInfo2 storage pool = poolInfo2[_pid];
        UserInfo storage user = userInfo2[_pid][msg.sender];
        require(user.amount <= pool.freeAmount);
        _safeTransfer(sfr, address(msg.sender), user.amount);
        emit EmergencyWithdraw2(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe rose transfer function, just in case if rounding error causes pool to not have enough ROSEs.
    function safeRoseTransfer(address _to, uint256 _amount) internal {
        uint256 roseBal = rose.balanceOf(address(this));
        if (_amount > roseBal) {
            rose.transfer(_to, roseBal);
        } else {
            rose.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    // Update dev address by the owner.
    function rank(address _addr) public onlyOwner {
        rankAddr = _addr;
    }

    // Update dev address by the owner.
    function community(address _addr) public onlyOwner {
        communityAddr = _addr;
    }

    // Fill _user in as referrer.
    function refer(address _user) external {
        require(_user != msg.sender && referrers[_user] != address(0));
        // No modification.
        require(referrers[msg.sender] == address(0));
        referrers[msg.sender] = _user;
        // Record two levels of refer relationship。
        referreds1[_user].push(msg.sender);
        address referrer2 = referrers[_user];
        if (_user != referrer2) {
            referreds2[referrer2].push(msg.sender);
        }
    }

    // Query the first referred user.
    function getReferreds1(address addr, uint256 startPos)
        external
        view
        returns (uint256 length, address[] memory data)
    {
        address[] memory referreds = referreds1[addr];
        length = referreds.length;
        data = new address[](length);
        for (uint256 i = 0; i < 5 && i + startPos < length; i++) {
            data[i] = referreds[startPos + i];
        }
    }

    // Query the second referred user.
    function getReferreds2(address addr, uint256 startPos)
        external
        view
        returns (uint256 length, address[] memory data)
    {
        address[] memory referreds = referreds2[addr];
        length = referreds.length;
        data = new address[](length);
        for (uint256 i = 0; i < 5 && i + startPos < length; i++) {
            data[i] = referreds[startPos + i];
        }
    }

    // Query user all rewards
    function allPendingRose(address _user)
        external
        view
        returns (uint256 pending)
    {
        for (uint256 i = 0; i < poolInfo1.length; i++) {
            pending = pending.add(pendingRose1(i, _user));
        }
        for (uint256 i = 0; i < poolInfo2.length; i++) {
            pending = pending.add(pendingRose2(i, _user));
        }
    }

    // Mint for referrers.
    function mintReferralReward(uint256 _amount) internal {
        address referrer = referrers[msg.sender];
        // no referrer.
        if (address(0) == referrer) {
            return;
        }
        // mint for user and the first level referrer.
        rose.mint(msg.sender, _amount.div(100));
        rose.mint(referrer, _amount.mul(2).div(100));

        // only the referrer of the top person is himself.
        if (referrers[referrer] == referrer) {
            return;
        }
        // mint for the second level referrer.
        rose.mint(referrers[referrer], _amount.mul(2).div(100));
    }

    // Update the locked amount that meet the conditions
    function updateLockedAmount(PoolInfo2 storage pool) internal {
        uint256 passedBlock = block.number - pool.lastUnlockedBlock;
        if (passedBlock >= pool.unlockIntervalBlock) {
            // case 2 and more than 2 period have passed.
            pool.lastUnlockedBlock = pool.lastUnlockedBlock.add(
                pool.unlockIntervalBlock.mul(
                    passedBlock.div(pool.unlockIntervalBlock)
                )
            );
            uint256 lockedAmount = pool.lockedAmount;
            pool.lockedAmount = 0;
            pool.freeAmount = pool.freeAmount.add(lockedAmount);
        } else if (pool.lockedAmount >= pool.maxLockAmount) {
            // Free 75% to freeAmont from lockedAmount.
            uint256 freeAmount = pool.lockedAmount.mul(75).div(100);
            pool.lockedAmount = pool.lockedAmount.sub(freeAmount);
            pool.freeAmount = pool.freeAmount.add(freeAmount);
        }
    }

    // Using feeAmount to buy back ROSE and share every holder.
    function convert(uint256 _pid) external {
        PoolInfo2 storage pool = poolInfo2[_pid];
        uint256 lpSupply = pool.freeAmount.add(pool.lockedAmount);
        if (address(sfr2rose) != address(0) && pool.feeAmount > 0) {
            uint256 amountOut = swapSFRForROSE(pool.feeAmount);
            if (amountOut > 0) {
                pool.feeAmount = 0;
                pool.sharedFeeAmount = pool.sharedFeeAmount.add(amountOut);
                pool.accRosePerShare = pool.accRosePerShare.add(
                    amountOut.mul(1e12).div(lpSupply)
                );
            }
        }
    }

    function swapSFRForROSE(uint256 _amount)
        internal
        returns (uint256 amountOut)
    {
        (uint256 reserve0, uint256 reserve1, ) = sfr2rose.getReserves();
        address token0 = sfr2rose.token0();
        (uint256 reserveIn, uint256 reserveOut) = token0 == sfr
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        // Calculate information required to swap
        uint256 amountInWithFee = _amount.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
        if (amountOut == 0) {
            return 0;
        }
        (uint256 amount0Out, uint256 amount1Out) = token0 == sfr
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        _safeTransfer(sfr, address(sfr2rose), _amount);
        sfr2rose.swap(amount0Out, amount1Out, address(this), new bytes(0));
    }

    // Wrapper for safeTransferFrom
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    // Wrapper for safeTransfer
    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        IERC20(token).safeTransfer(to, amount);
    }
}

