// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Masterchef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per second.
        uint256 lastRewardTime; // Last timestamp number that Reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated Reward per share, times 1e18. See below.
        uint256 lpSupply;
    }

    // The Reward TOKEN!
    IERC20 public immutable rewardToken;
    // Reward tokens created per second.
    uint256 public rewardPerSecond;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The timestamp number when Reward mining starts.
    uint256 public startTime;
    // Maximum rewardPerSecond
    uint256 public MAX_EMISSION_RATE = 10 ether;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event addPool(uint256 indexed pid, address lpToken, uint256 allocPoint);
    event setPool(uint256 indexed pid, address lpToken, uint256 allocPoint);
    event UpdateEmissionRate(address indexed user, uint256 rewardPerSecond);
    event UpdateStartTime(uint256 newStartBlock);

    constructor(IERC20 _rewardToken, uint256 _rewardPerSecond, uint256 _startTime, address _owner) Ownable(_owner) {
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        startTime = _startTime;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;

    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) external onlyOwner nonDuplicated(_lpToken) {
        // valid ERC20 token
        _lpToken.balanceOf(address(this));

        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExistence[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTime: lastRewardTime,
                accRewardPerShare: 0,
                lpSupply: 0
            })
        );

        emit addPool(poolInfo.length - 1, address(_lpToken), _allocPoint);
    }

    // Update the given pool's Reward allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        emit setPool(_pid, address(poolInfo[_pid].lpToken), _allocPoint);
    }

    // Return reward multiplier over the given _from to _to timestamp.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to - _from;
    }

    // View function to see pending Reward on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        if (block.timestamp > pool.lastRewardTime && pool.lpSupply != 0 && totalAllocPoint > 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 reward = ((multiplier * rewardPerSecond) * pool.allocPoint) / totalAllocPoint;
            accRewardPerShare = ((accRewardPerShare + reward) * 1e18) / pool.lpSupply;
        }
        return ((user.amount * accRewardPerShare) / 1e18) - user.rewardDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        if (pool.lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 reward = ((multiplier * rewardPerSecond) * pool.allocPoint) / totalAllocPoint;
        pool.accRewardPerShare = ((pool.accRewardPerShare + reward) * 1e18) / pool.lpSupply;
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for Reward allocation.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = ((user.amount * pool.accRewardPerShare) / 1e18) - user.rewardDebt;
            if (pending > 0) {
                safeRewardTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 balanceBefore = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            _amount = pool.lpToken.balanceOf(address(this)) - balanceBefore;

            user.amount = user.amount + _amount;
            pool.lpSupply = pool.lpSupply + _amount;
        }
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = ((user.amount * pool.accRewardPerShare) / 1e18) - user.rewardDebt;
        if (pending > 0) {
            safeRewardTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            pool.lpSupply = pool.lpSupply - _amount;
        }
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);

        if (pool.lpSupply >= amount) {
            pool.lpSupply = pool.lpSupply - amount;
        } else {
            pool.lpSupply = 0;
        }

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe Reward transfer function, just in case if rounding error causes pool to not have enough Reward.
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBal = rewardToken.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > rewardBal) {
            transferSuccess = rewardToken.transfer(_to, rewardBal);
        } else {
            transferSuccess = rewardToken.transfer(_to, _amount);
        }
        require(transferSuccess, "safeRewardTransfer: transfer failed");
    }

    // Masterchef has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _rewardPerSecond) external onlyOwner {
        require(_rewardPerSecond <= MAX_EMISSION_RATE, "INCORRECT INPUT");
        massUpdatePools();
        rewardPerSecond = _rewardPerSecond;
        emit UpdateEmissionRate(msg.sender, _rewardPerSecond);
    }

    // Only update before start of farm. Must be future dated. Cannot be called if farm has started.
    function updateStartTime(uint256 _newStartTime) external onlyOwner {
        require(block.timestamp < startTime, "FARM ALREADY STARTED");
        require(block.timestamp < _newStartTime, "INCORRECT INPUT");
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardTime = _newStartTime;
        }

        startTime = _newStartTime;

        emit UpdateStartTime(startTime);
    }
}
