// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.7.6;
pragma abicoder v2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import {Powered} from "./PowerSwitch/Powered.sol";
import {IUniversalVault} from "./Vault.sol";
import {IRewardPool} from "./RewardPool.sol";
import {IFactory} from "./Factory/IFactory.sol";
import {IVaultFactory} from "./Factory/IVaultFactory.sol";
import {IInstanceRegistry} from "./Factory/InstanceRegistry.sol";

interface IStakingCenterTimed {
    event StakingCenterCreated(address rewardPool, address powerSwitch);
    event StakingCenterFunded(uint256 amount, uint256 duration);
    event BonusTokenRegistered(address token);
    event VaultFactoryRegistered(address factory);

    event Staked(address vault, uint256 amount);
    event Unstaked(address vault, uint256 amount, bool harvest);
    event RewardClaimed(address vault, address token, uint256 amount);

    struct StakingCenterData {
        address stakingToken;
        address rewardToken;
        address rewardPool;
        uint256 rewardSharesOutstanding;
        uint256 totalStake;
        uint256 totalStakeUnits;
        uint256 lastUpdate;
        uint256 lockDuration;
        RewardSchedule[] rewardSchedules;
    }

    struct RewardSchedule {
        uint256 duration;
        uint256 start;
        uint256 shares;
    }

    struct VaultData {
        address owner;
        uint256 totalStake;
        StakeData[] stakes;
    }

    struct StakeData {
        uint256 amount;
        uint256 start;
        uint256 timestamp;
    }

    struct RewardOutput {
        uint256 reward;
        uint256 newTotalStakeUnits;
    }

    function stake(address vault, uint256 amount, bytes calldata permission) external;

    function unstakeAndClaim(address vault, uint256 stakeIndex, bool harvest, bytes calldata permission) external;

    function getStakingCenterData() external view returns (StakingCenterData memory stakingCenter);

    function getCurrentUnlockedRewards() external view returns (uint256 unlockedRewards);
    
    function getFutureUnlockedRewards(uint256 timestamp) external view returns (uint256 unlockedRewards);

    function getBonusTokenSetLength() external view returns (uint256 length);

    function getBonusTokenAtIndex(uint256 index) external view returns (address bonusToken);

    function isValidAddress(address target) external view returns (bool validity);

    function getCurrentTotalStakeUnits() external view returns (uint256 totalStakeUnits);

    function getFutureTotalStakeUnits(uint256 timestamp) external view returns (uint256 totalStakeUnits);

    function getVaultData(address vault) external view returns (VaultData memory vaultData);

    function getCurrentStakeReward(address vault, uint256 stakeIndex) external view returns (uint256 reward);

    function getFutureStakeReward(address vault, uint256 stakeIndex, uint256 timestamp) external view returns (uint256 reward);

    function getCurrentVaultStakeUnits(address vault) external view returns (uint256 stakeUnits);

    function getFutureVaultStakeUnits(address vault, uint256 timestamp) external view returns (uint256 stakeUnits);

    function calculateTotalStakeUnits(StakeData[] memory stakes, uint256 timestamp) external pure returns (uint256 totalStakeUnits);

    function calculateStakeUnits(uint256 amount, uint256 start, uint256 end) external pure returns (uint256 stakeUnits);

    function calculateRewardFromStakes(StakeData memory stakeData, uint256 unlockedRewards,
        uint256 totalStakeUnits, uint256 timestamp) external pure returns (RewardOutput memory out);

    function calculateReward(uint256 unlockedRewards, uint256 stakeAmount, uint256 stakeDuration,
        uint256 totalStakeUnits) external pure returns (uint256 reward);

    function calculateUnlockedRewards(RewardSchedule[] memory rewardSchedules, uint256 rewardBalance,
        uint256 sharesOutstanding, uint256 timestamp) external pure returns (uint256 unlockedRewards);
}

contract StakingCenterTimed is IStakingCenterTimed, Powered, OwnableUpgradeable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    uint256 public constant MAX_STAKES_PER_VAULT = 30;
    uint256 public constant MAX_REWARD_TOKENS = 50;
    uint256 public constant BASE_SHARES_PER_WEI = 1000000;

    StakingCenterData private _stakingCenter;
    mapping(address => VaultData) private _vaults;
    mapping(address => uint256) private _rewardsEarned;
    EnumerableSet.AddressSet private _bonusTokenSet;
    address private _vaultFactory;

    function initializeLock() external initializer {}

    function initialize(
        address ownerAddress,
        address rewardPoolFactory,
        address powerSwitchFactory,
        address vaultFactory,
        address stakingToken,
        address rewardToken,
        uint256 lockDuration
    ) external initializer {
        // deploy power switch
        address powerSwitch = IFactory(powerSwitchFactory).create(abi.encode(ownerAddress));

        // deploy reward pool
        address rewardPool = IFactory(rewardPoolFactory).create(abi.encode(powerSwitch));

        // set internal configs
        OwnableUpgradeable.__Ownable_init();
        OwnableUpgradeable.transferOwnership(ownerAddress);
        Powered._setPowerSwitch(powerSwitch);

        // commit to storage
        _stakingCenter.stakingToken = stakingToken;
        _stakingCenter.rewardToken = rewardToken;
        _stakingCenter.rewardPool = rewardPool;
        _stakingCenter.lockDuration = lockDuration;

        _vaultFactory = vaultFactory;

        // emit event
        emit StakingCenterCreated(rewardPool, powerSwitch);
    }

    function getBonusTokenSetLength() external view override returns (uint256 length) {
        return _bonusTokenSet.length();
    }

    function getBonusTokenAtIndex(uint256 index) external view override returns (address bonusToken) {
        return _bonusTokenSet.at(index);
    }

    function isValidAddress(address target) public view override returns (bool validity) {
        // sanity check target for potential input errors
        return
            target != address(this) &&
            target != address(0) &&
            target != _stakingCenter.stakingToken &&
            target != _stakingCenter.rewardToken &&
            target != _stakingCenter.rewardPool &&
            !_bonusTokenSet.contains(target);
    }

    function getStakingCenterData() external view override returns (StakingCenterData memory stakingCenter) {
        return _stakingCenter;
    }

    function getCurrentUnlockedRewards() public view override returns (uint256 unlockedRewards) {
        // calculate reward available based on state
        return getFutureUnlockedRewards(block.timestamp);
    }

    function getFutureUnlockedRewards(uint256 timestamp) public view override returns (uint256 unlockedRewards) {
        // get reward amount remaining
        uint256 remainingRewards = IERC20(_stakingCenter.rewardToken).balanceOf(_stakingCenter.rewardPool);
        // calculate reward available based on state
        unlockedRewards = calculateUnlockedRewards(
            _stakingCenter.rewardSchedules,
            remainingRewards,
            _stakingCenter.rewardSharesOutstanding,
            timestamp
        );
        // explicit return
        return unlockedRewards;
    }

    function getCurrentTotalStakeUnits() public view override returns (uint256 totalStakeUnits) {
        // calculate new stake units
        return getFutureTotalStakeUnits(block.timestamp);
    }

    function getFutureTotalStakeUnits(uint256 timestamp) public view override returns (uint256 totalStakeUnits) {
        // return early if no change
        if (timestamp == _stakingCenter.lastUpdate) return _stakingCenter.totalStakeUnits;
        // calculate new stake units
        uint256 newStakeUnits = calculateStakeUnits(_stakingCenter.totalStake, _stakingCenter.lastUpdate, timestamp);
        // add to cached total
        totalStakeUnits = _stakingCenter.totalStakeUnits.add(newStakeUnits);
        // explicit return
        return totalStakeUnits;
    }

    function getVaultData(address vault) external view override returns (VaultData memory vaultData) {
        return _vaults[vault];
    }

    function getCurrentStakeReward(address vault, uint256 stakeIndex) external view override returns (uint256 reward) {
        // calculate rewards
        return
            calculateRewardFromStakes(
                _vaults[vault]
                    .stakes[stakeIndex],
                getCurrentUnlockedRewards(),
                getCurrentTotalStakeUnits(),
                block
                    .timestamp
            )
                .reward;
    }

    function getFutureStakeReward(
        address vault,
        uint256 stakeIndex,
        uint256 timestamp
    ) external view override returns (uint256 reward) {
        // calculate rewards
        return
            calculateRewardFromStakes(
                _vaults[vault]
                    .stakes[stakeIndex],
                getFutureUnlockedRewards(timestamp),
                getFutureTotalStakeUnits(timestamp),
                timestamp
            )
                .reward;
    }

    function getCurrentVaultStakeUnits(address vault) public view override returns (uint256 stakeUnits) {
        // calculate stake units
        return getFutureVaultStakeUnits(vault, block.timestamp);
    }

    function getFutureVaultStakeUnits(address vault, uint256 timestamp)
        public
        view
        override
        returns (uint256 stakeUnits)
    {
        // calculate stake units
        return calculateTotalStakeUnits(_vaults[vault].stakes, timestamp);
    }

    function calculateTotalStakeUnits(StakeData[] memory stakes, uint256 timestamp)
        public
        pure
        override
        returns (uint256 totalStakeUnits)
    {
        for (uint256 index; index < stakes.length; index++) {
            // reference stake
            StakeData memory stakeData = stakes[index];
            // calculate stake units
            uint256 stakeUnits = calculateStakeUnits(stakeData.amount, stakeData.timestamp, timestamp);
            // add to running total
            totalStakeUnits = totalStakeUnits.add(stakeUnits);
        }
    }

    function calculateStakeUnits(
        uint256 amount,
        uint256 start,
        uint256 end
    ) public pure override returns (uint256 stakeUnits) {
        // calculate duration
        uint256 duration = end.sub(start);
        // calculate stake units
        stakeUnits = duration.mul(amount);
        // explicit return
        return stakeUnits;
    }

    function fundStakingCenter(uint256 amount, uint256 duration) external onlyOwner onlyOnline {
        // validate duration
        require(duration != 0, "StakingCenter: invalid duration");

        // create new reward shares
        // if existing rewards on this StakingCenter
        //   mint new shares proportional to % change in rewards remaining
        //   newShares = remainingShares * newReward / remainingRewards
        // else
        //   mint new shares with BASE_SHARES_PER_WEI initial conversion rate
        //   store as fixed point number with same  of decimals as reward token
        uint256 newRewardShares;
        if (_stakingCenter.rewardSharesOutstanding > 0) {
            uint256 remainingRewards = IERC20(_stakingCenter.rewardToken).balanceOf(_stakingCenter.rewardPool);
            newRewardShares = _stakingCenter.rewardSharesOutstanding.mul(amount).div(remainingRewards);
        } else {
            newRewardShares = amount.mul(BASE_SHARES_PER_WEI);
        }

        // add reward shares to total
        _stakingCenter.rewardSharesOutstanding = _stakingCenter.rewardSharesOutstanding.add(newRewardShares);

        // store new reward schedule
        _stakingCenter.rewardSchedules.push(RewardSchedule(duration, block.timestamp, newRewardShares));

        // transfer reward tokens to reward pool
        TransferHelper.safeTransfer(_stakingCenter.rewardToken, _stakingCenter.rewardPool, amount);

        // emit event
        emit StakingCenterFunded(amount, duration);
    }

    function registerVaultFactory(address factory) external onlyOwner notShutdown {
        // add factory to set
        require(isValidAddress(factory), "StakingCenter: vault factory already registered");

        _vaultFactory = factory;

        // emit event
        emit VaultFactoryRegistered(factory);
    }

    function registerBonusToken(address bonusToken) external onlyOwner onlyOnline {
        // verify valid bonus token
        require(isValidAddress(bonusToken));

        // verify bonus token count
        require(_bonusTokenSet.length() < MAX_REWARD_TOKENS, "StakingCenter: max bonus tokens reached ");

        // add token to set
        assert(_bonusTokenSet.add(bonusToken));

        // emit event
        emit BonusTokenRegistered(bonusToken);
    }

    function calculateRewardFromStakes(
        StakeData memory stakeData,
        uint256 unlockedRewards,
        uint256 totalStakeUnits,
        uint256 timestamp
    ) public pure override returns (RewardOutput memory out) {
        // calculate stake duration
        uint256 stakeDuration = timestamp.sub(stakeData.timestamp);
        uint256 currentAmount = stakeData.amount;

        // calculate reward amount
        uint256 currentReward =
            calculateReward(unlockedRewards, currentAmount, stakeDuration, totalStakeUnits);

        // update cumulative reward
        out.reward = out.reward.add(currentReward);

        // update cached unlockedRewards
        unlockedRewards = unlockedRewards.sub(currentReward);

        // calculate time weighted stake
        uint256 stakeUnits = currentAmount.mul(stakeDuration);

        // update cached totalStakeUnits
        totalStakeUnits = totalStakeUnits.sub(stakeUnits);

        // explicit return
        return RewardOutput(out.reward, totalStakeUnits);
    }

    // TODO: Test to ensure that the reward scaling is correct
    function calculateReward(
        uint256 unlockedRewards,
        uint256 stakeAmount,
        uint256 stakeDuration,
        uint256 totalStakeUnits
    ) public pure override returns (uint256 reward) {
        // calculate time weighted stake
        uint256 stakeUnits = stakeAmount.mul(stakeDuration);

        // calculate base reward
        reward = 0;
        if (totalStakeUnits != 0) {
            // scale reward according to proportional weight
            reward = unlockedRewards.mul(stakeUnits).div(totalStakeUnits);
        }

        // explicit return
        return reward;
    }

    function calculateUnlockedRewards(
        RewardSchedule[] memory rewardSchedules,
        uint256 rewardBalance,
        uint256 sharesOutstanding,
        uint256 timestamp
    ) public pure override returns (uint256 unlockedRewards) {
        // return 0 if no registered schedules
        if (rewardSchedules.length == 0) {
            return 0;
        }

        // calculate reward shares locked across all reward schedules
        uint256 sharesLocked;
        for (uint256 index = 0; index < rewardSchedules.length; index++) {
            // fetch reward schedule storage reference
            RewardSchedule memory schedule = rewardSchedules[index];

            // caculate amount of shares available on this schedule
            uint256 currentSharesLocked = 0;
            if (timestamp.sub(schedule.start) < schedule.duration) {
                currentSharesLocked = schedule.shares.sub(
                    schedule.shares.mul(timestamp.sub(schedule.start)).div(schedule.duration)
                );
            }

            // add to running total
            sharesLocked = sharesLocked.add(currentSharesLocked);
        }

        // convert shares to reward
        uint256 rewardLocked = sharesLocked.mul(rewardBalance).div(sharesOutstanding);

        // calculate amount available
        unlockedRewards = rewardBalance.sub(rewardLocked);

        // explicit return
        return unlockedRewards;
    }

    function stake(
        address vault,
        uint256 amount,
        bytes calldata permission
    ) external override onlyOnline {
        // verify non-zero amount
        require(amount != 0);

        // verify the vault is a valid vault and ONLY one of ours
        require(IInstanceRegistry(_vaultFactory).isInstance(vault), "StakingCenter: Invalid vault");

        // send tokens to vault
        IERC20(_stakingCenter.stakingToken).transferFrom(msg.sender, vault, amount);

        // fetch vault storage reference
        VaultData storage vaultData = _vaults[vault];

        // verify stakes boundary not reached
        require(vaultData.stakes.length < MAX_STAKES_PER_VAULT, "StakingCenter: MAX_STAKES_PER_VAULT reached");

        // update cached sum of stake units across all vaults
        _updateTotalStakeUnits();

        // store amount and timestamp
        vaultData.stakes.push(StakeData(amount, block.timestamp, block.timestamp));

        // update cached total vault and StakingCenter amounts
        vaultData.totalStake = vaultData.totalStake.add(amount);
        _stakingCenter.totalStake = _stakingCenter.totalStake.add(amount);

        // call lock on vault
        IUniversalVault(vault).lock(_stakingCenter.stakingToken, amount, permission);

        // emit event
        vaultData.owner = msg.sender;
        emit Staked(vault, amount);
    }

    function unstakeAndClaim(
        address vault,
        uint256 stakeIndex,
        bool harvest,
        bytes calldata permission
    ) external override onlyOnline {
        // verify the vault is a valid vault and ONLY one of ours
        require(IInstanceRegistry(_vaultFactory).isInstance(vault));
        
        // fetch vault storage reference
        VaultData storage vaultData = _vaults[vault];
        require(vaultData.owner == msg.sender, "incorrect owner");
        // verify the index exists
        require(stakeIndex < vaultData.stakes.length, "invalid stake");
        StakeData storage stakeData = vaultData.stakes[stakeIndex];

        // check for sufficient vault stake amount
        require(vaultData.totalStake >= stakeData.amount);

        // check for sufficient StakingCenter stake amount
        // if this check fails, there is a bug in stake accounting
        assert(_stakingCenter.totalStake >= stakeData.amount);

        if (!harvest) {
            // verify the user has staked for required time
            uint256 endTime = stakeData.start + _stakingCenter.lockDuration;
            require(block.timestamp >= endTime, "unstaking too early");
        }

        // update cached sum of stake units across all vaults
        _updateTotalStakeUnits();

        // get reward amount remaining
        uint256 remainingRewards = IERC20(_stakingCenter.rewardToken).balanceOf(_stakingCenter.rewardPool);

        // calculate vested portion of reward pool
        uint256 unlockedRewards =
            calculateUnlockedRewards(
                _stakingCenter.rewardSchedules,
                remainingRewards,
                _stakingCenter.rewardSharesOutstanding,
                block.timestamp
            );

        // calculate vault time weighted reward with scaling
        RewardOutput memory out =
            calculateRewardFromStakes(
                stakeData,
                unlockedRewards,
                _stakingCenter.totalStakeUnits,
                block.timestamp
            );

        if (!harvest) {
            // update cached stake totals
            vaultData.totalStake = vaultData.totalStake.sub(stakeData.amount);
            _stakingCenter.totalStake = _stakingCenter.totalStake.sub(stakeData.amount);
            _stakingCenter.totalStakeUnits = out.newTotalStakeUnits;

            // unlock staking tokens from vault
            IUniversalVault(vault).unlock(_stakingCenter.stakingToken, stakeData.amount, true, permission);
        }

        // emit event
        emit Unstaked(vault, stakeData.amount, harvest);

        // only perform on non-zero reward
        if (out.reward > 0) {
            // calculate shares to burn
            // sharesToBurn = sharesOutstanding * reward / remainingRewards
            uint256 sharesToBurn = _stakingCenter.rewardSharesOutstanding.mul(out.reward).div(remainingRewards);

            // burn claimed shares
            _stakingCenter.rewardSharesOutstanding = _stakingCenter.rewardSharesOutstanding.sub(sharesToBurn);

            // transfer bonus tokens from reward pool to recipient
            if (_bonusTokenSet.length() > 0) {
                for (uint256 index = 0; index < _bonusTokenSet.length(); index++) {
                    // fetch bonus token address reference
                    address bonusToken = _bonusTokenSet.at(index);

                    // calculate bonus token amount
                    // bonusAmount = bonusRemaining * reward / remainingRewards
                    uint256 bonusAmount =
                        IERC20(bonusToken).balanceOf(_stakingCenter.rewardPool).mul(out.reward).div(remainingRewards);

                    // transfer if amount is non-zero
                    if (bonusAmount > 0) {
                        // transfer bonus token
                        IRewardPool(_stakingCenter.rewardPool).sendERC20(bonusToken, vaultData.owner, bonusAmount);

                        // emit event
                        emit RewardClaimed(vault, bonusToken, bonusAmount);
                    }
                }
            }

            // transfer reward tokens from reward pool to recipient
            IRewardPool(_stakingCenter.rewardPool).sendERC20(_stakingCenter.rewardToken, vaultData.owner, out.reward);
            _rewardsEarned[vault] = _rewardsEarned[vault].add(out.reward);

            if (harvest) {
                // update start time on stakes
                vaultData.stakes[stakeIndex].timestamp = block.timestamp;
            } else {
                // merge the list after deleting stake
                for (uint256 i = stakeIndex; i < vaultData.stakes.length - 1; i++){
                    vaultData.stakes[i] = vaultData.stakes[i + 1];
                }
                vaultData.stakes.pop();

                // update stake data in storage
                if (vaultData.stakes.length == 0) {
                    // all stakes have been unstaked
                    delete vaultData.stakes;
                }
            }

            // emit event
            emit RewardClaimed(vault, _stakingCenter.rewardToken, out.reward);
        }
    }

    function _updateTotalStakeUnits() private {
        // update cached totalStakeUnits
        _stakingCenter.totalStakeUnits = getCurrentTotalStakeUnits();
        // update cached lastUpdate
        _stakingCenter.lastUpdate = block.timestamp;
    }
}
