## Yield Farm with Flexible Token Reward

Yield farming / staking smart contract that has an ability to use any elected ERC20 token as its distributed reward.

### Solidity Version
- 0.8.20

### Imports
- @openzeppelin/contracts/utils/ReentrancyGuard.sol
- @openzeppelin/contracts/access/Ownable.sol
- @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

### Constructor Agruments
- _rewardToken: ERC20 contract address that will be used for the farming/staking rewards
- _rewardPerSecond: The number of tokens that will be allocated to farmers/stakers each second
- _startTime: The block timestamp the rewards will start distributing to farmers/stakers
- _owner: The elected owner of this yield farming smart contract

### Functions
- add: Add a new lp to the pool. Can only be called by the owner.
- set: Update the given pool's Reward allocation point and deposit fee. Can only be called by the owner.
- getMultiplier: Return reward multiplier over the given _from to _to timestamp.
- pendingReward: View function to see pending Reward on frontend.
- massUpdatePools: Update reward variables for all pools. Be careful of gas spending!
- updatePool: Update reward variables of the given pool to be up-to-date.
- deposit: Deposit LP tokens to MasterChef for Reward allocation.
- withdraw: Withdraw LP tokens from MasterChef.
- emergencyWithdraw: Withdraw without caring about rewards. EMERGENCY ONLY.
- safeRewardTransfer: Safe Reward transfer function, just in case if rounding error causes pool to not have enough Reward.
- updateEmissionRate: Masterchef has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
- updateStartTime: Only update before start of farm. Must be future dated. Cannot be called if farm has started.
